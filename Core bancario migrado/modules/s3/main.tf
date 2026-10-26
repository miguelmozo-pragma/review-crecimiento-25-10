###########################################
########### KMS (opcional) ################
###########################################

resource "aws_kms_key" "this" {
  provider = aws.project
  count    = local.create_kms_key ? 1 : 0

  description             = "KMS key for S3 bucket ${local.bucket_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    { Name = "${local.base_name}-kms-s3-${var.bucket_name}" },
    var.additional_tags
  )
}

resource "aws_kms_alias" "this" {
  provider = aws.project
  count    = local.create_kms_key ? 1 : 0

  name          = local.kms_key_alias
  target_key_id = aws_kms_key.this[0].key_id
}

###########################################
########### S3 Bucket #####################
###########################################

resource "aws_s3_bucket" "this" {
  provider = aws.project

  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    { Name = local.bucket_name },
    var.additional_tags
  )
}

###########################################
########### Public Access Block ###########
###########################################

resource "aws_s3_bucket_public_access_block" "this" {
  provider = aws.project
  bucket   = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###########################################
########### Ownership controls ############
###########################################

resource "aws_s3_bucket_ownership_controls" "this" {
  provider = aws.project
  bucket   = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

###########################################
########### Versioning ####################
###########################################

resource "aws_s3_bucket_versioning" "this" {
  provider = aws.project
  bucket   = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

###########################################
########### Server-side encryption ########
###########################################

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  provider = aws.project
  bucket   = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_key_arn
    }
    bucket_key_enabled = var.bucket_key_enabled
  }
}

###########################################
########### Lifecycle #####################
###########################################

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  provider = aws.project
  count    = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket   = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = rule.value.prefix
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }

      dynamic "transition" {
        for_each = rule.value.transition_days != null ? [1] : []
        content {
          days          = rule.value.transition_days
          storage_class = rule.value.transition_storage_class
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [1] : []
        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }
    }
  }
}

###########################################
########### Access logging ################
###########################################

resource "aws_s3_bucket_logging" "this" {
  provider = aws.project
  count    = var.logging_target_bucket != null ? 1 : 0
  bucket   = aws_s3_bucket.this.id

  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_target_prefix
}

###########################################
########### Bucket policy #################
# TLS obligatorio + restricción opcional al VPC endpoint
###########################################

data "aws_iam_policy_document" "bucket" {
  provider = aws.project

  # Denegar cualquier acceso que no use TLS
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Restringir acceso solo al VPC endpoint indicado (opcional)
  dynamic "statement" {
    for_each = var.restrict_to_vpc_endpoint_id != null ? [1] : []
    content {
      sid    = "RestrictToVpcEndpoint"
      effect = "Deny"
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      actions   = ["s3:*"]
      resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
      condition {
        test     = "StringNotEquals"
        variable = "aws:sourceVpce"
        values   = [var.restrict_to_vpc_endpoint_id]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  provider = aws.project
  bucket   = aws_s3_bucket.this.id
  policy   = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}
