###############################################
# Gobierno: Apps
# Ambiente: ALL
#
# Recursos:
#   - Namespaces de Kubernetes (frontend, public-access, administrative-access)
#   - Microservicios (ECR + IRSA + SA + Deployment/Service/Ingress + pipeline CI/CD)
###############################################

provider "aws" {
  alias   = "project"
  region  = var.region
  profile = var.profile != "" ? var.profile : null
  default_tags {
    tags = var.common_tags
  }
}

# Nombre determinístico del cluster para autenticar el provider de Kubernetes
locals {
  eks_cluster_name = "agat-${var.environment}-eks-${var.cluster_name}"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--region", var.region],
      var.profile != "" ? ["--profile", var.profile] : []
    )
  }
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
  }
  backend "s3" {
    region = "us-west-2"
  }
}
