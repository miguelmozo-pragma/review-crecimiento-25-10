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
  name     = "/cb/${var.environment}/networking/vpc-id"
}

data "aws_ssm_parameter" "vpc_cidr" {
  provider = aws.project
  name     = "/cb/${var.environment}/networking/vpc-cidr"
}

data "aws_ssm_parameter" "data_subnet_ids" {
  provider = aws.project
  name     = "/cb/${var.environment}/networking/data-subnet-ids"
}

locals {
  vpc_id          = data.aws_ssm_parameter.vpc_id.value
  vpc_cidr        = data.aws_ssm_parameter.vpc_cidr.value
  data_subnet_ids = split(",", data.aws_ssm_parameter.data_subnet_ids.value)

  base_name = "cb-${var.environment}"

  datasync_sg_name       = "${local.base_name}-sg-datasync-${var.datasync_name}"
  datasync_endpoint_name = "${local.base_name}-datasync-${var.datasync_name}-vpce"
}
