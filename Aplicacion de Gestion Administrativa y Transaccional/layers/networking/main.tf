###############################################
# Gobierno: Networking
# Ambiente: ALL
#
# Recursos:
#   - VPC (1)
#   - Subnets public/private/data (3 AZs)
#   - Internet Gateway (1)
#   - NAT Gateway (1)
#   - Route tables y asociaciones
#   - VPC Endpoint Gateway S3 (1)
#   - VPC Flow Logs (opcional)
#   - SSM Parameters con outputs del layer
###############################################

# ==========================================================================
# 1. VPC (red base del proyecto)
# ==========================================================================
module "vpc" {
  source = "../../modules/vpc-module"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Variables específicas
  name       = var.vpc_name
  cidr_block = var.cidr_block

  create_igw = var.create_igw
  create_nat = var.create_nat
  nat_mode   = var.nat_mode

  subnet_config = var.subnet_config
  vpc_endpoints = var.vpc_endpoints

  create_flow_logs           = var.create_flow_logs
  flow_log_retention_in_days = var.flow_log_retention_in_days

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 2. Publicación de outputs en SSM Parameter Store
#    Patrón: /agat/{environment}/networking/{recurso}
# ==========================================================================
resource "aws_ssm_parameter" "vpc_id" {
  provider = aws.project
  name     = "/agat/${var.environment}/networking/vpc-id"
  type     = "String"
  value    = module.vpc.vpc_id
  tags     = merge({ Name = "/agat/${var.environment}/networking/vpc-id" }, var.common_tags)
}

resource "aws_ssm_parameter" "vpc_cidr" {
  provider = aws.project
  name     = "/agat/${var.environment}/networking/vpc-cidr"
  type     = "String"
  value    = module.vpc.vpc_cidr_block
  tags     = merge({ Name = "/agat/${var.environment}/networking/vpc-cidr" }, var.common_tags)
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  provider = aws.project
  name     = "/agat/${var.environment}/networking/private-subnet-ids"
  type     = "StringList"
  value    = join(",", module.vpc.subnet_ids_by_service["private"])
  tags     = merge({ Name = "/agat/${var.environment}/networking/private-subnet-ids" }, var.common_tags)
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  provider = aws.project
  count    = contains(keys(var.subnet_config), "public") ? 1 : 0
  name     = "/agat/${var.environment}/networking/public-subnet-ids"
  type     = "StringList"
  value    = join(",", module.vpc.subnet_ids_by_service["public"])
  tags     = merge({ Name = "/agat/${var.environment}/networking/public-subnet-ids" }, var.common_tags)
}

resource "aws_ssm_parameter" "data_subnet_ids" {
  provider = aws.project
  count    = contains(keys(var.subnet_config), "data") ? 1 : 0
  name     = "/agat/${var.environment}/networking/data-subnet-ids"
  type     = "StringList"
  value    = join(",", module.vpc.subnet_ids_by_service["data"])
  tags     = merge({ Name = "/agat/${var.environment}/networking/data-subnet-ids" }, var.common_tags)
}
