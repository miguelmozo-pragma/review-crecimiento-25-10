###############################################
# Gobierno: Storage
# Ambiente: ALL
#
# Recursos:
#   - Provider aws.project con default_tags
#   - Backend S3 (config vía -backend-config en ejecución local)
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
