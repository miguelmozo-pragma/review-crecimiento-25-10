###########################################
# Local values - naming and computed values
# Naming pattern: cb-{environment}-{componente}-{funcionalidad}
# component literal for this module = "elasticache"
###########################################

locals {
  base_name = "cb-${var.environment}"

  # Resource names ({componente} = elasticache literal, per naming conventions)
  # replication_group_id is kept lowercase and <= 40 chars (inputs validated in variables.tf)
  replication_group_id = lower("${local.base_name}-elasticache-${var.name}")
  subnet_group_name    = "${local.base_name}-elasticache-${var.name}"
  sg_name              = "${local.base_name}-sg-elasticache-${var.name}"
  kms_key_name         = "${local.base_name}-kms-elasticache-${var.name}"
  kms_alias            = "alias/${local.base_name}-kms-elasticache-${var.name}"

  # KMS create-or-use branch: create a dedicated CMK only when no ARN is provided
  create_kms  = var.kms_key_arn == null
  kms_key_arn = local.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn

  # Cross-field coherence clamping so single-node callers never trip AWS-side errors:
  # failover requires >= 2 nodes; multi-az requires failover.
  effective_failover = var.num_cache_clusters > 1 ? var.automatic_failover_enabled : false
  effective_multi_az = local.effective_failover ? var.multi_az_enabled : false
}
