###############################################
# Gobierno: Data
# Ambiente: ALL
#
# Recursos:
#   - Aurora PostgreSQL (cluster writer + reader opcional)
#   - ElastiCache Redis (replication group)
#   - S3 bucket (objetos)
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
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
  backend "s3" {
    region = "us-west-2"
  }
}
