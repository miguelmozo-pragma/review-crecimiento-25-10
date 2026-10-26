locals {
  # Convención de nomenclatura Core Bancario: cb-{environment}-{componente}-{funcionalidad}
  # El componente (s3) se incluye como literal, no se pasa como variable.
  base_name = "cb-${var.environment}"

  bucket_name   = "${local.base_name}-s3-${var.bucket_name}"
  kms_key_alias = "alias/${local.base_name}-kms-s3-${var.bucket_name}"

  # Usa KMS key propia si no se pasó una por variable
  create_kms_key = var.kms_key_arn == null
  kms_key_arn    = local.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
}
