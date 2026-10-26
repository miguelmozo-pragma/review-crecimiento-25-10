###############################################
# Module: S3 Bucket
#
# Resources:
#   - KMS CMK dedicated to the bucket (optional, create-or-use)
#   - KMS alias
#   - S3 bucket (SSE-KMS mandatory, bucket key enabled)
#   - Versioning
#   - Public access block (all blocked)
#   - Lifecycle rules (optional)
#   - Bucket policy (optional)
###############################################

# ==========================================================================
# 1. KMS Customer Managed Key (dedicated to this bucket)
# ==========================================================================
resource "aws_kms_key" "this" {
  count    = var.create_kms_key ? 1 : 0
  provider = aws.project

  description             = "CMK for S3 bucket ${local.bucket_name}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365

  tags = merge(
    { Name = "${local.base_name}-kms-s3-${var.bucket_name}" },
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
# 2. S3 Bucket
# ==========================================================================
resource "aws_s3_bucket" "this" {
  provider = aws.project

  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    { Name = local.bucket_name },
    var.additional_tags
  )
}

# ==========================================================================
# 3. Versioning
# ==========================================================================
resource "aws_s3_bucket_versioning" "this" {
  provider = aws.project

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# ==========================================================================
# 4. Encryption at rest (SSE-KMS mandatory, bucket key enabled)
# ==========================================================================
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  provider = aws.project

  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# ==========================================================================
# 5. Public access block (always blocked)
# ==========================================================================
resource "aws_s3_bucket_public_access_block" "this" {
  provider = aws.project

  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# ==========================================================================
# 6. Lifecycle rules (optional)
# ==========================================================================
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  provider = aws.project
  count    = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  # Explicit dependency: lifecycle config requires versioning to be configured first
  depends_on = [aws_s3_bucket_versioning.this]

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
# 7. Bucket policy (optional)
# ==========================================================================
resource "aws_s3_bucket_policy" "this" {
  provider = aws.project
  count    = var.bucket_policy != null ? 1 : 0

  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy

  depends_on = [aws_s3_bucket_public_access_block.this]
}
