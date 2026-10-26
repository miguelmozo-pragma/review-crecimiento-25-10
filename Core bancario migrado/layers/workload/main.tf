###############################################
# Gobierno: Workload
# Ambiente: ALL
#
# Recursos:
#   - EKS cluster (1) + managed node groups
#   - Addons: AWS Load Balancer Controller, EBS CSI, Karpenter
#   - SSM Parameters con outputs del layer
###############################################

# ==========================================================================
# 1. Cluster EKS + addons
# ==========================================================================
module "eks" {
  source = "../../modules/eks"
  providers = {
    aws.project = aws.project
    kubernetes  = kubernetes
    helm        = helm
    kubectl     = kubectl
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Cluster
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # Node groups
  node_groups = var.node_groups

  # Addons
  enable_lb_controller = var.enable_lb_controller
  ebs_csi_driver       = var.ebs_csi_driver

  # Karpenter
  enable_karpenter            = var.enable_karpenter
  karpenter_chart_version     = var.karpenter_chart_version
  karpenter_subnet_ids        = local.private_subnet_ids
  karpenter_capacity_types    = var.karpenter_capacity_types
  karpenter_node_cpu_limit    = var.karpenter_node_cpu_limit
  karpenter_node_memory_limit = var.karpenter_node_memory_limit

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 2. Publicación de outputs en SSM Parameter Store
#    Patrón: /cb/{environment}/workload/{recurso}
# ==========================================================================
resource "aws_ssm_parameter" "eks_cluster_name" {
  provider = aws.project
  name     = "/cb/${var.environment}/workload/eks-cluster-name"
  type     = "String"
  value    = module.eks.cluster_name
  tags     = merge({ Name = "/cb/${var.environment}/workload/eks-cluster-name" }, var.common_tags)
}

resource "aws_ssm_parameter" "eks_cluster_endpoint" {
  provider = aws.project
  name     = "/cb/${var.environment}/workload/eks-cluster-endpoint"
  type     = "String"
  value    = module.eks.cluster_endpoint
  tags     = merge({ Name = "/cb/${var.environment}/workload/eks-cluster-endpoint" }, var.common_tags)
}

resource "aws_ssm_parameter" "eks_oidc_provider_arn" {
  provider = aws.project
  name     = "/cb/${var.environment}/workload/eks-oidc-provider-arn"
  type     = "String"
  value    = module.eks.oidc_provider_arn
  tags     = merge({ Name = "/cb/${var.environment}/workload/eks-oidc-provider-arn" }, var.common_tags)
}
