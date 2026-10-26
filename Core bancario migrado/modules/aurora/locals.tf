###########################################
# Local values - naming and computed values
###########################################

locals {
  base_name = "cb-${var.environment}"

  # Resource names ({componente} = aurora literal, per naming conventions)
  cluster_name      = "${local.base_name}-aurora-${var.cluster_name}"
  writer_name       = "${local.base_name}-aurora-${var.cluster_name}-writer"
  reader_name       = "${local.base_name}-aurora-${var.cluster_name}-reader"
  subnet_group_name = "${local.base_name}-aurora-${var.cluster_name}-subnet-group"
  sg_name           = "${local.base_name}-sg-aurora-${var.cluster_name}"
  kms_alias_name    = "alias/${local.base_name}-kms-aurora-${var.cluster_name}"
  kms_key_desc      = "KMS key for Aurora PostgreSQL ${local.cluster_name}"
  secret_name       = "${local.base_name}-secret-aurora-${var.cluster_name}"

  # Port
  port = 5432

  # KMS create-or-use branch: create a dedicated CMK only when no ARN is provided
  create_kms  = var.kms_key_arn == null
  kms_key_arn = local.create_kms ? aws_kms_key.aurora[0].arn : var.kms_key_arn
}
