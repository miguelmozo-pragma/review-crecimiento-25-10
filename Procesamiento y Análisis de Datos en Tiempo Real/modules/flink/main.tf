###############################################
# Module: Amazon Managed Service for Apache Flink
#
# Resources:
#   - Dedicated CloudWatch Logs CMK + alias
#   - CloudWatch Log Group (encrypted) + Log Stream
#   - IAM execution role + policy (least privilege)
#   - Managed Service for Apache Flink application (kinesisanalyticsv2)
#   - Application CloudWatch logging option
###############################################

# ==========================================================================
# 0. Context
# ==========================================================================
data "aws_caller_identity" "current" {
  provider = aws.project
}

# ==========================================================================
# 1. CloudWatch logging (dedicated CMK + log group)
# ==========================================================================
data "aws_iam_policy_document" "cw_kms" {
  count    = var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

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

  description             = "CMK for CloudWatch Logs of ${local.application_name}"
  deletion_window_in_days = var.cloudwatch_kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.cw_kms[0].json

  tags = merge(
    { Name = "${local.base_name}-kms-cw-flink-${var.application_name}" },
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
# 2. IAM execution role (least privilege)
# ==========================================================================
data "aws_iam_policy_document" "assume" {
  count    = var.create_execution_role ? 1 : 0
  provider = aws.project

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["kinesisanalytics.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count    = var.create_execution_role ? 1 : 0
  provider = aws.project

  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume[0].json

  tags = merge(
    { Name = local.role_name },
    var.additional_tags
  )
}

data "aws_iam_policy_document" "permissions" {
  count    = var.create_execution_role ? 1 : 0
  provider = aws.project

  # Read the application code artifact from S3
  statement {
    sid    = "CodeArtifactRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      var.code_bucket_arn,
      "${var.code_bucket_arn}/*"
    ]
  }

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

  # Invoke Fraud Detector for predictions
  statement {
    sid    = "FraudDetectorInvoke"
    effect = "Allow"
    actions = [
      "frauddetector:GetEventPrediction"
    ]
    resources = length(var.fraud_detector_arns) > 0 ? var.fraud_detector_arns : ["*"]
  }

  # Write processed output to S3 buckets (data lake)
  dynamic "statement" {
    for_each = length(var.output_bucket_arns) > 0 ? [1] : []
    content {
      sid    = "OutputS3Write"
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      resources = concat(
        var.output_bucket_arns,
        [for arn in var.output_bucket_arns : "${arn}/*"]
      )
    }
  }

  # Use the CMKs protecting Kinesis source and output buckets
  dynamic "statement" {
    for_each = length(local.kms_usage_arns) > 0 ? [1] : []
    content {
      sid    = "KmsUsage"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = local.kms_usage_arns
    }
  }

  # Write application logs to CloudWatch
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      aws_cloudwatch_log_group.this.arn,
      "${aws_cloudwatch_log_group.this.arn}:*"
    ]
  }

  # Publish application metrics
  statement {
    sid       = "CloudWatchMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "this" {
  count    = var.create_execution_role ? 1 : 0
  provider = aws.project

  name   = "${local.role_name}-policy"
  role   = aws_iam_role.this[0].id
  policy = data.aws_iam_policy_document.permissions[0].json
}

# ==========================================================================
# 3. Managed Service for Apache Flink application
# ==========================================================================
resource "aws_kinesisanalyticsv2_application" "this" {
  provider = aws.project

  name                   = local.application_name
  description            = var.application_description
  runtime_environment    = var.runtime_environment
  service_execution_role = local.execution_role_arn
  start_application      = var.start_application

  application_configuration {
    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn = var.code_bucket_arn
          file_key   = var.code_object_key
        }
      }
      code_content_type = "ZIPFILE"
    }

    flink_application_configuration {
      checkpoint_configuration {
        configuration_type            = "CUSTOM"
        checkpointing_enabled         = var.checkpointing_enabled
        checkpoint_interval           = var.checkpoint_interval
        min_pause_between_checkpoints = var.min_pause_between_checkpoints
      }

      monitoring_configuration {
        configuration_type = "CUSTOM"
        log_level          = var.log_level
        metrics_level      = var.metrics_level
      }

      parallelism_configuration {
        configuration_type   = "CUSTOM"
        auto_scaling_enabled = var.auto_scaling_enabled
        parallelism          = var.parallelism
        parallelism_per_kpu  = var.parallelism_per_kpu
      }
    }

    dynamic "environment_properties" {
      for_each = length(var.property_groups) > 0 ? [1] : []
      content {
        dynamic "property_group" {
          for_each = var.property_groups
          content {
            property_group_id = property_group.value.group_id
            property_map      = property_group.value.property_map
          }
        }
      }
    }
  }

  cloudwatch_logging_options {
    log_stream_arn = aws_cloudwatch_log_stream.this.arn
  }

  tags = merge(
    { Name = local.application_name },
    var.additional_tags
  )
}
