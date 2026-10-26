locals {
  base_name = "rtda-${var.environment}"

  # rtda-{env}-fraud-{funcionalidad}  e.g. rtda-dev-fraud-fraude
  # Used for the training-data S3 bucket and the service role.
  bucket_name = "${local.base_name}-fraud-${var.name}${var.resource_suffix}"
  role_name   = "${local.base_name}-fraud-${var.name}-role"

  # rtda-{env}-kms-fraud  (dedicated CMK for Fraud Detector data)
  kms_alias_name = "alias/${local.base_name}-kms-fraud-${var.name}"

  # Create-or-use KMS branch centralized in a single local.
  kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn

  # CloudWatch log group: /rtda/{env}/fraud/{funcionalidad}
  log_group_name = "/rtda/${var.environment}/fraud/${var.name}"

  # Dedicated CloudWatch Logs CMK alias
  cw_kms_alias_name = "alias/${local.base_name}-kms-cw-fraud-${var.name}"

  cloudwatch_kms_key_arn = var.create_cloudwatch_kms_key ? aws_kms_key.cw[0].arn : var.cloudwatch_kms_key_arn
}
