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
# Cluster EKS (para autenticación y datos del OIDC)
###############################################

data "aws_eks_cluster" "this" {
  provider = aws.project
  name     = local.eks_cluster_name
}

###############################################
# OIDC provider ARN publicado por el layer workload (vía SSM)
###############################################

data "aws_ssm_parameter" "oidc_provider_arn" {
  provider = aws.project
  name     = "/agat/${var.environment}/workload/eks-oidc-provider-arn"
}

locals {
  oidc_provider_arn = data.aws_ssm_parameter.oidc_provider_arn.value
  # URL del OIDC sin el prefijo https:// (requerido por el trust IRSA)
  oidc_provider_url = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}
