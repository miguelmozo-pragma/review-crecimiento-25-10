locals {
  # Convención de nomenclatura Core Bancario: cb-{environment}-{componente}-{funcionalidad}
  # El componente (dms) se incluye como literal, no se pasa como variable.
  base_name = "cb-${var.environment}"

  replication_instance_id = "${local.base_name}-dms-${var.name}"
  subnet_group_id         = "${local.base_name}-dms-${var.name}-subnet-group"
  source_endpoint_id      = "${local.base_name}-dms-${var.name}-source"
  target_endpoint_id      = "${local.base_name}-dms-${var.name}-target"
  task_id                 = "${local.base_name}-dms-${var.name}-task"
  sg_name                 = "${local.base_name}-sg-dms-${var.name}"
  secret_name             = "${local.base_name}-secret-dms-${var.name}"
  kms_alias               = "alias/${local.base_name}-kms-dms-${var.name}"

  # KMS create-or-use branch
  create_kms  = var.kms_key_arn == null
  kms_key_arn = local.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn

  # Table mappings por defecto: migrar todas las tablas de todos los schemas
  default_table_mappings = jsonencode({
    rules = [
      {
        "rule-type" = "selection"
        "rule-id"   = "1"
        "rule-name" = "1"
        "object-locator" = {
          "schema-name" = "%"
          "table-name"  = "%"
        }
        "rule-action" = "include"
      }
    ]
  })

  table_mappings = var.table_mappings != null ? var.table_mappings : local.default_table_mappings
}
