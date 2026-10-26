###############################################
# Module: Lake Formation
#
# Resources:
#   - Data lake settings (optional, account-global)
#   - IAM role for registered S3 location (optional, create-or-use)
#   - Lake Formation S3 location registration
#   - Glue Data Catalog database
#   - Glue Data Catalog tables (optional)
#   - Fine-grained Lake Formation permissions (database / table)
###############################################

# ==========================================================================
# 1. Data lake settings (account-global, optional ownership)
#    Only one module/layer in the account should manage this resource.
# ==========================================================================
resource "aws_lakeformation_data_lake_settings" "this" {
  count    = var.manage_data_lake_settings ? 1 : 0
  provider = aws.project

  admins = var.data_lake_admins
}

# ==========================================================================
# 2. IAM role for the registered S3 location (least privilege)
# ==========================================================================
data "aws_iam_policy_document" "register_assume" {
  count    = var.create_registration_role ? 1 : 0
  provider = aws.project

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lakeformation.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "register" {
  count    = var.create_registration_role ? 1 : 0
  provider = aws.project

  name               = local.registration_role_name
  assume_role_policy = data.aws_iam_policy_document.register_assume[0].json

  tags = merge(
    { Name = local.registration_role_name },
    var.additional_tags
  )
}

data "aws_iam_policy_document" "register_permissions" {
  count    = var.create_registration_role ? 1 : 0
  provider = aws.project

  # Read/write objects in the registered S3 location
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      var.s3_location_arn,
      "${var.s3_location_arn}/*"
    ]
  }

  # Use the CMK protecting the S3 location (when provided)
  dynamic "statement" {
    for_each = var.s3_location_kms_key_arn != "" ? [1] : []
    content {
      sid    = "KmsAccess"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ]
      resources = [var.s3_location_kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "register" {
  count    = var.create_registration_role ? 1 : 0
  provider = aws.project

  name   = "${local.registration_role_name}-policy"
  role   = aws_iam_role.register[0].id
  policy = data.aws_iam_policy_document.register_permissions[0].json
}

# ==========================================================================
# 3. Register the S3 location in Lake Formation
# ==========================================================================
resource "aws_lakeformation_resource" "this" {
  provider = aws.project

  arn = var.s3_location_arn

  # Use the service-linked role, a created custom role, or an external role.
  use_service_linked_role = var.use_service_linked_role
  role_arn = var.use_service_linked_role ? null : (
    var.create_registration_role ? aws_iam_role.register[0].arn : var.registration_role_arn
  )

  depends_on = [aws_iam_role_policy.register]
}

# ==========================================================================
# 4. Glue Data Catalog database
# ==========================================================================
resource "aws_glue_catalog_database" "this" {
  provider = aws.project

  name        = local.database_name
  description = var.database_description

  location_uri = var.database_location_uri != "" ? var.database_location_uri : null
}

# ==========================================================================
# 5. Glue Data Catalog tables (optional)
# ==========================================================================
resource "aws_glue_catalog_table" "this" {
  for_each = local.tables
  provider = aws.project

  name          = each.value.name
  database_name = aws_glue_catalog_database.this.name
  description   = each.value.description
  table_type    = each.value.table_type

  dynamic "partition_keys" {
    for_each = each.value.partition_keys
    content {
      name    = partition_keys.value.name
      type    = partition_keys.value.type
      comment = partition_keys.value.comment
    }
  }

  storage_descriptor {
    location      = each.value.location
    input_format  = each.value.input_format
    output_format = each.value.output_format

    dynamic "columns" {
      for_each = each.value.columns
      content {
        name    = columns.value.name
        type    = columns.value.type
        comment = columns.value.comment
      }
    }

    ser_de_info {
      name                  = each.value.ser_de_name
      serialization_library = each.value.ser_de_library
    }
  }
}

# ==========================================================================
# 6. Fine-grained permissions — database level
# ==========================================================================
resource "aws_lakeformation_permissions" "database" {
  for_each = local.database_permissions
  provider = aws.project

  principal                     = each.value.principal
  permissions                   = each.value.permissions
  permissions_with_grant_option = each.value.permissions_with_grant_opt

  database {
    name = aws_glue_catalog_database.this.name
  }

  depends_on = [aws_lakeformation_resource.this]
}

# ==========================================================================
# 7. Fine-grained permissions — table level
# ==========================================================================
resource "aws_lakeformation_permissions" "table" {
  for_each = local.table_permissions
  provider = aws.project

  principal                     = each.value.principal
  permissions                   = each.value.permissions
  permissions_with_grant_option = each.value.permissions_with_grant_opt

  table {
    database_name = aws_glue_catalog_database.this.name
    name          = each.value.wildcard ? null : each.value.table
    wildcard      = each.value.wildcard
  }

  depends_on = [
    aws_lakeformation_resource.this,
    aws_glue_catalog_table.this
  ]
}
