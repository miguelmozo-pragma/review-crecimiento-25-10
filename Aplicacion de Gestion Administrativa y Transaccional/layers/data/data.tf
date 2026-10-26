###############################################
# Data Sources
###############################################

data "aws_caller_identity" "current" {
  provider = aws.project
}

data "aws_region" "current" {
  provider = aws.project
}

###############################################
# Outputs del layer networking (vía SSM)
###############################################

data "aws_ssm_parameter" "vpc_id" {
  provider = aws.project
  name     = "/agat/${var.environment}/networking/vpc-id"
}

data "aws_ssm_parameter" "vpc_cidr" {
  provider = aws.project
  name     = "/agat/${var.environment}/networking/vpc-cidr"
}

data "aws_ssm_parameter" "data_subnet_ids" {
  provider = aws.project
  name     = "/agat/${var.environment}/networking/data-subnet-ids"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  provider = aws.project
  name     = "/agat/${var.environment}/networking/private-subnet-ids"
}

locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  vpc_cidr           = data.aws_ssm_parameter.vpc_cidr.value
  data_subnet_ids    = split(",", data.aws_ssm_parameter.data_subnet_ids.value)
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)

  # Los pods EKS corren en las subnets privadas (VPC CNI, target-type ip).
  # Permitimos acceso a Aurora/Redis desde el CIDR de la VPC (incluye private + data).
  db_allowed_cidrs = [local.vpc_cidr]
}
