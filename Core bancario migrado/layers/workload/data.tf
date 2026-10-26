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

data "aws_ssm_parameter" "private_subnet_ids" {
  provider = aws.project
  name     = "/cb/${var.environment}/networking/private-subnet-ids"
}

locals {
  vpc_id             = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
}

###############################################
# Autenticación contra el cluster EKS
# El nombre es determinístico: cb-{env}-eks-{cluster_name}
###############################################

data "aws_eks_cluster" "this" {
  provider   = aws.project
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  provider   = aws.project
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}
