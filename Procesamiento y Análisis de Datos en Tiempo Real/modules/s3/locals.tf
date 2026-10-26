locals {
  base_name = "rtda-${var.environment}"

  # rtda-{env}-s3-{funcionalidad}  e.g. rtda-dev-s3-raw / rtda-dev-s3-datalake
  bucket_name = "${local.base_name}-s3-${var.bucket_name}${var.resource_suffix}"

  # rtda-{env}-kms-s3  (dedicated CMK for S3)
  kms_alias_name = "alias/${local.base_name}-kms-s3-${var.bucket_name}"

  # Create-or-use KMS branch centralized in a single local.
  # S3 data lake must always use SSE-KMS (never AES256), so a key is always resolved.
  kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
}
