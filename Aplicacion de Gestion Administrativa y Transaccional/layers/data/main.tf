###############################################
# Gobierno: Data
# Ambiente: ALL
#
# Recursos:
#   - Aurora PostgreSQL (writer + reader opcional)
#   - SSM Parameters con outputs del layer
###############################################

# ==========================================================================
# 1. Aurora PostgreSQL
# ==========================================================================
module "aurora" {
  source = "../../modules/aurora"
  providers = {
    aws.project = aws.project
  }

  project     = var.project
  environment = var.environment
  aws_region  = var.region

  cluster_name   = var.aurora_cluster_name
  engine_version = var.aurora_engine_version
  instance_class = var.aurora_instance_class
  database_name  = var.aurora_database_name

  vpc_id              = local.vpc_id
  subnet_ids          = local.data_subnet_ids
  allowed_cidr_blocks = local.db_allowed_cidrs

  create_read_replica = var.aurora_create_read_replica
  deletion_protection = var.aurora_deletion_protection

  additional_tags = var.common_tags
}

# ==========================================================================
# 2. Publicación de outputs en SSM Parameter Store
#    Patrón: /agat/{environment}/data/{recurso}
# ==========================================================================
resource "aws_ssm_parameter" "aurora_endpoint" {
  provider = aws.project
  name     = "/agat/${var.environment}/data/aurora-endpoint"
  type     = "String"
  value    = module.aurora.cluster_endpoint
  tags     = merge({ Name = "/agat/${var.environment}/data/aurora-endpoint" }, var.common_tags)
}

resource "aws_ssm_parameter" "aurora_reader_endpoint" {
  provider = aws.project
  name     = "/agat/${var.environment}/data/aurora-reader-endpoint"
  type     = "String"
  value    = module.aurora.reader_endpoint
  tags     = merge({ Name = "/agat/${var.environment}/data/aurora-reader-endpoint" }, var.common_tags)
}

resource "aws_ssm_parameter" "aurora_secret_arn" {
  provider = aws.project
  name     = "/agat/${var.environment}/data/aurora-secret-arn"
  type     = "String"
  value    = module.aurora.secret_arn
  tags     = merge({ Name = "/agat/${var.environment}/data/aurora-secret-arn" }, var.common_tags)
}
