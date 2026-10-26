###############################################
# Module: Kinesis Data Firehose
#
# Resources:
#   - CloudWatch Log Group (encrypted) + Log Stream
#   - IAM role + policy (least privilege) for the delivery stream
#   - Firehose delivery stream (Kinesis source -> S3 destination, SSE-KMS)
###############################################

# ==========================================================================
# 0. Context
# ==========================================================================
data "aws_caller_identity" "current" {
  provider = aws.project
}

# ==========================================================================
# 1. CloudWatch logging for the delivery stream
# ==========================================================================

# Dedicated CMK for CloudWatch Logs with a key policy that lets the logs
# service encrypt/decrypt the log group (required for CloudWatch Logs SSE-KMS).
data "aws_iam_policy_document" "cw_kms" {
  count    = var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

  # Account root retains full administrative control of the key
  statement {
    sid       = "EnableRootPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Allow the CloudWatch Logs service to use the key for this log group
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"]
    }
  }
}

resource "aws_kms_key" "cw" {
  count    = var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

  description             = "CMK for CloudWatch Logs of ${local.delivery_name}"
  deletion_window_in_days = var.cloudwatch_kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.cw_kms[0].json

  tags = merge(
    { Name = "${local.base_name}-kms-cw-${var.name}" },
    var.additional_tags
  )
}

resource "aws_kms_alias" "cw" {
  count    = var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

  name          = local.cw_kms_alias_name
  target_key_id = aws_kms_key.cw[0].key_id
}

resource "aws_cloudwatch_log_group" "this" {
  provider = aws.project

  name              = local.log_group_name
  retention_in_days = var.log_retention_in_days
  kms_key_id        = local.cloudwatch_kms_key_arn != "" ? local.cloudwatch_kms_key_arn : null

  tags = merge(
    { Name = local.log_group_name },
    var.additional_tags
  )
}

resource "aws_cloudwatch_log_stream" "this" {
  provider = aws.project

  name           = local.log_stream_name
  log_group_name = aws_cloudwatch_log_group.this.name
}

# ==========================================================================
# 2. IAM role for Firehose (least privilege)
# ==========================================================================
data "aws_iam_policy_document" "assume" {
  provider = aws.project

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  provider = aws.project

  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = merge(
    { Name = local.role_name },
    var.additional_tags
  )
}

data "aws_iam_policy_document" "permissions" {
  provider = aws.project

  # Read records from the source Kinesis stream
  statement {
    sid    = "KinesisSourceRead"
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    resources = [var.kinesis_stream_arn]
  }

  # Write delivered objects to the destination S3 bucket
  statement {
    sid    = "S3Delivery"
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    resources = [
      var.destination_bucket_arn,
      "${var.destination_bucket_arn}/*"
    ]
  }

  # Use the destination S3 CMK and the source Kinesis CMK
  statement {
    sid    = "KmsUsage"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = distinct([
      var.destination_kms_key_arn,
      var.kinesis_stream_kms_key_arn
    ])
  }

  # Write delivery logs to CloudWatch
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "this" {
  provider = aws.project

  name   = "${local.role_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

# ==========================================================================
# 3. Firehose delivery stream (Kinesis source -> S3 destination)
# ==========================================================================
resource "aws_kinesis_firehose_delivery_stream" "this" {
  provider = aws.project

  name        = local.delivery_name
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = var.kinesis_stream_arn
    role_arn           = aws_iam_role.this.arn
  }

  # NOTE: server_side_encryption (SSE of the delivery stream itself) is NOT set
  # here on purpose. AWS forbids delivery-stream SSE when the source is a
  # Kinesis Data Stream (it conflicts with kinesis_source_configuration): the
  # records already arrive encrypted from Kinesis and Firehose decrypts them
  # with its role. Encryption at rest of the destination is still enforced
  # below via kms_key_arn, which writes every S3 object with the CMK.

  extended_s3_configuration {
    role_arn            = aws_iam_role.this.arn
    bucket_arn          = var.destination_bucket_arn
    prefix              = var.s3_prefix
    error_output_prefix = var.s3_error_output_prefix

    buffering_size     = var.buffering_size
    buffering_interval = var.buffering_interval
    compression_format = var.compression_format

    # Encrypt delivered objects with the destination S3 CMK
    kms_key_arn = var.destination_kms_key_arn

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.this.name
      log_stream_name = aws_cloudwatch_log_stream.this.name
    }
  }

  tags = merge(
    { Name = local.delivery_name },
    var.additional_tags
  )
}
