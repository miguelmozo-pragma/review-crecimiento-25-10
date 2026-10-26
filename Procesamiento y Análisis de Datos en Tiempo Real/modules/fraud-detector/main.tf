###############################################
# Module: Fraud Detector (peripheral resources)
#
# Resources:
#   - Dedicated data CMK (fraud) + alias
#   - Training-data S3 bucket (SSE-KMS, private) + versioning + lifecycle
#   - Dedicated CloudWatch Logs CMK + log group
#   - IAM service role + policy (least privilege)
#
# NOTE: The detector, variables, labels, eventType, outcomes, rules and
# models are NOT managed here (no native Terraform support). They are
# created outside Terraform (console/CLI/API).
###############################################

# ==========================================================================
# 0. Context
# ==========================================================================
data "aws_caller_identity" "current" {
  provider = aws.project
}

# ==========================================================================
# 1. Data CMK dedicated to Fraud Detector
# ==========================================================================
resource "aws_kms_key" "this" {
  count    = var.create_kms_key ? 1 : 0
  provider = aws.project

  description             = "CMK for Fraud Detector data ${local.base_name}-fraud-${var.name}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365

  tags = merge(
    { Name = "${local.base_name}-kms-fraud-${var.name}" },
    var.additional_tags
  )
}

resource "aws_kms_alias" "this" {
  count    = var.create_kms_key ? 1 : 0
  provider = aws.project

  name          = local.kms_alias_name
  target_key_id = aws_kms_key.this[0].key_id
}

# ==========================================================================
# 2. Training-data S3 bucket (SSE-KMS, private)
# ==========================================================================
resource "aws_s3_bucket" "training" {
  count    = var.create_training_bucket ? 1 : 0
  provider = aws.project

  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    { Name = local.bucket_name },
    var.additional_tags
  )
}

resource "aws_s3_bucket_versioning" "training" {
  count    = var.create_training_bucket ? 1 : 0
  provider = aws.project

  bucket = aws_s3_bucket.training[0].id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "training" {
  count    = var.create_training_bucket ? 1 : 0
  provider = aws.project

  bucket = aws_s3_bucket.training[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "training" {
  count    = var.create_training_bucket ? 1 : 0
  provider = aws.project

  bucket = aws_s3_bucket.training[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "training" {
  count    = var.create_training_bucket && length(var.lifecycle_rules) > 0 ? 1 : 0
  provider = aws.project

  bucket     = aws_s3_bucket.training[0].id
  depends_on = [aws_s3_bucket_versioning.training]

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = rule.value.prefix
      }

      dynamic "transition" {
        for_each = rule.value.transition
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      expiration {
        days = rule.value.expiration_days
      }

      noncurrent_version_expiration {
        noncurrent_days = rule.value.noncurrent_version_expiration_days
      }
    }
  }
}

# ==========================================================================
# 3. CloudWatch logging (dedicated CMK + log group)
# ==========================================================================
data "aws_iam_policy_document" "cw_kms" {
  count    = var.create_log_group && var.create_cloudwatch_kms_key ? 1 : 0
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
  count    = var.create_log_group && var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

  description             = "CMK for CloudWatch Logs of ${local.base_name}-fraud-${var.name}"
  deletion_window_in_days = var.cloudwatch_kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.cw_kms[0].json

  tags = merge(
    { Name = "${local.base_name}-kms-cw-fraud-${var.name}" },
    var.additional_tags
  )
}

resource "aws_kms_alias" "cw" {
  count    = var.create_log_group && var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

  name          = local.cw_kms_alias_name
  target_key_id = aws_kms_key.cw[0].key_id
}

resource "aws_cloudwatch_log_group" "this" {
  count    = var.create_log_group ? 1 : 0
  provider = aws.project

  name              = local.log_group_name
  retention_in_days = var.log_retention_in_days
  kms_key_id = var.create_cloudwatch_kms_key ? aws_kms_key.cw[0].arn : (
    var.cloudwatch_kms_key_arn != "" ? var.cloudwatch_kms_key_arn : null
  )

  tags = merge(
    { Name = local.log_group_name },
    var.additional_tags
  )
}

# ==========================================================================
# 4. IAM service role for Fraud Detector (least privilege)
# ==========================================================================
data "aws_iam_policy_document" "assume" {
  count    = var.create_service_role ? 1 : 0
  provider = aws.project

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["frauddetector.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count    = var.create_service_role ? 1 : 0
  provider = aws.project

  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume[0].json

  tags = merge(
    { Name = local.role_name },
    var.additional_tags
  )
}

data "aws_iam_policy_document" "permissions" {
  count    = var.create_service_role ? 1 : 0
  provider = aws.project

  # Read training data from the training bucket
  dynamic "statement" {
    for_each = var.create_training_bucket ? [1] : []
    content {
      sid    = "TrainingDataRead"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      resources = [
        aws_s3_bucket.training[0].arn,
        "${aws_s3_bucket.training[0].arn}/*"
      ]
    }
  }

  # Use the data CMK
  statement {
    sid    = "DataKmsUsage"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [local.kms_key_arn]
  }

  # Publish Fraud Detector metrics
  statement {
    sid       = "CloudWatchMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }

  # Write to the Fraud Detector log group
  dynamic "statement" {
    for_each = var.create_log_group ? [1] : []
    content {
      sid    = "CloudWatchLogs"
      effect = "Allow"
      actions = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = [
        aws_cloudwatch_log_group.this[0].arn,
        "${aws_cloudwatch_log_group.this[0].arn}:*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "this" {
  count    = var.create_service_role ? 1 : 0
  provider = aws.project

  name   = "${local.role_name}-policy"
  role   = aws_iam_role.this[0].id
  policy = data.aws_iam_policy_document.permissions[0].json
}
