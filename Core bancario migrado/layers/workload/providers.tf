###############################################
# Gobierno: Workload
# Ambiente: ALL
#
# Recursos:
#   - EKS cluster (1) + managed node groups
#   - Addons: AWS Load Balancer Controller, EBS CSI, Karpenter
#   - SSM Parameters con outputs del layer
###############################################

provider "aws" {
  alias   = "project"
  region  = var.region
  profile = var.profile != "" ? var.profile : null
  default_tags {
    tags = var.common_tags
  }
}

# Nombre determinístico del cluster, usado para autenticar los providers de k8s
# sin crear un ciclo con los outputs del módulo EKS.
locals {
  eks_cluster_name = "cb-${var.environment}-eks-${var.cluster_name}"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = concat(
      ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--region", var.region],
      var.profile != "" ? ["--profile", var.profile] : []
    )
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = concat(
        ["eks", "get-token", "--cluster-name", local.eks_cluster_name, "--region", var.region],
        var.profile != "" ? ["--profile", var.profile] : []
      )
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

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
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
  backend "s3" {
    region = "us-west-2"
  }
}
