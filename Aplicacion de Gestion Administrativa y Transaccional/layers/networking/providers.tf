###############################################
# Gobierno: Networking
# Ambiente: ALL
#
# Recursos:
#   - VPC (1)
#   - Subnets (public, private, data) en 3 AZs
#   - Internet Gateway (1)
#   - NAT Gateway zonal (1)
#   - Route tables y asociaciones
#   - VPC Endpoint Gateway S3 (1)
#   - VPC Flow Logs (opcional)
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

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
  backend "s3" {
    region = "us-west-2"
  }
}
