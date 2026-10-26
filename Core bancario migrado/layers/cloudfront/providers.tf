###############################################
# Gobierno: CloudFront
# Ambiente: ALL
#
# Recursos:
#   - CloudFront VPC Origin apuntando al ALB interno (cb-prod-alb-public)
#   - CloudFront Distribution (acceso público al portal)
###############################################

provider "aws" {
  alias   = "project"
  region  = var.region
  profile = var.profile != "" ? var.profile : null
  default_tags {
    tags = var.common_tags
  }
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.68.0"
    }
  }
  backend "s3" {
    region = "us-west-2"
  }
}
