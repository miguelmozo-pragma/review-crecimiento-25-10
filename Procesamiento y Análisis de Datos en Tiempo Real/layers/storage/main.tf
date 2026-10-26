###############################################
# Gobierno: Storage
# Ambiente: ALL
#
# Recursos:
#   - S3 bucket RAW + KMS CMK (1)
#   - S3 bucket DATA LAKE + KMS CMK (1)
#   - Lake Formation (registro S3, Glue database, permisos) (1)
#   - SSM Parameters para comunicación entre layers (varios)
###############################################

# ==========================================================================
# 1. Bucket RAW (destino de Kinesis Data Firehose)
# ==========================================================================
module "s3_raw" {
  source = "../../modules/s3"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Variables específicas
  bucket_name        = var.raw_bucket_name
  force_destroy      = var.raw_force_destroy
  versioning_enabled = var.raw_versioning_enabled
  lifecycle_rules    = var.raw_lifecycle_rules

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 2. Bucket DATA LAKE (consumo analítico, gobernado por Lake Formation)
# ==========================================================================
module "s3_datalake" {
  source = "../../modules/s3"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Variables específicas
  bucket_name        = var.datalake_bucket_name
  force_destroy      = var.datalake_force_destroy
  versioning_enabled = var.datalake_versioning_enabled
  lifecycle_rules    = var.datalake_lifecycle_rules

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 3. Lake Formation — gobierno del Data Lake
# ==========================================================================
module "lakeformation" {
  source = "../../modules/lakeformation"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Registro de la ubicación S3 del data lake
  s3_location_arn         = module.s3_datalake.bucket_arn
  s3_location_kms_key_arn = module.s3_datalake.kms_key_arn
  use_service_linked_role = var.use_service_linked_role

  # Data lake settings (opcional, recurso global de la cuenta)
  manage_data_lake_settings = var.manage_data_lake_settings
  data_lake_admins          = var.data_lake_admins

  # Catálogo
  database_name         = var.database_name
  database_description  = var.database_description
  database_location_uri = "s3://${module.s3_datalake.bucket_name}/"

  # Permisos de grano fino
  database_permissions = var.database_permissions
  table_permissions    = var.table_permissions

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 4. SSM Parameters — comunicación entre layers
# ==========================================================================

# --- Bucket RAW ---
resource "aws_ssm_parameter" "raw_bucket_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/raw-bucket-name"
  type     = "String"
  value    = module.s3_raw.bucket_name
  tags     = merge({ Name = "/rtda/${var.environment}/storage/raw-bucket-name" }, var.common_tags)
}

resource "aws_ssm_parameter" "raw_bucket_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/raw-bucket-arn"
  type     = "String"
  value    = module.s3_raw.bucket_arn
  tags     = merge({ Name = "/rtda/${var.environment}/storage/raw-bucket-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "raw_kms_key_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/raw-kms-key-arn"
  type     = "String"
  value    = module.s3_raw.kms_key_arn
  tags     = merge({ Name = "/rtda/${var.environment}/storage/raw-kms-key-arn" }, var.common_tags)
}

# --- Bucket DATA LAKE ---
resource "aws_ssm_parameter" "datalake_bucket_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/datalake-bucket-name"
  type     = "String"
  value    = module.s3_datalake.bucket_name
  tags     = merge({ Name = "/rtda/${var.environment}/storage/datalake-bucket-name" }, var.common_tags)
}

resource "aws_ssm_parameter" "datalake_bucket_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/datalake-bucket-arn"
  type     = "String"
  value    = module.s3_datalake.bucket_arn
  tags     = merge({ Name = "/rtda/${var.environment}/storage/datalake-bucket-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "datalake_kms_key_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/datalake-kms-key-arn"
  type     = "String"
  value    = module.s3_datalake.kms_key_arn
  tags     = merge({ Name = "/rtda/${var.environment}/storage/datalake-kms-key-arn" }, var.common_tags)
}

# --- Lake Formation / Glue database ---
resource "aws_ssm_parameter" "datalake_database_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/datalake-database-name"
  type     = "String"
  value    = module.lakeformation.database_name
  tags     = merge({ Name = "/rtda/${var.environment}/storage/datalake-database-name" }, var.common_tags)
}
