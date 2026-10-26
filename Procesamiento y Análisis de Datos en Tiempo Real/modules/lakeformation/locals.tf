locals {
  base_name = "rtda-${var.environment}"

  # Glue database logical name: rtda-{env}-lakeformation-{funcionalidad}
  # e.g. rtda-dev-lakeformation-datalake
  # Glue database names cannot contain hyphens in some engines, but the Glue
  # Data Catalog accepts them; keep the convention for consistency.
  database_name = "${local.base_name}-lakeformation-${var.database_name}"

  # IAM role name for the Lake Formation service-linked data access role (optional)
  registration_role_name = "${local.base_name}-lakeformation-${var.database_name}-register-role"

  # Normalize table definitions into a map keyed by table name for for_each
  tables = { for t in var.tables : t.name => t }

  # Flatten database-level permissions into a map keyed by a stable id
  database_permissions = {
    for p in var.database_permissions :
    "${p.principal}" => p
  }

  # Flatten table-level permissions into a map keyed by principal + table.
  # When wildcard is true, use "*" as the table segment so the key stays stable.
  table_permissions = {
    for p in var.table_permissions :
    "${p.principal}::${p.wildcard ? "*" : p.table}" => p
  }
}
