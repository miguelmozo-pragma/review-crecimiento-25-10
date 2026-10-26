###############################################
# Gobierno: Migration
# Ambiente: ALL
#
# Recursos:
#   - DMS (replication instance, endpoints, task, KMS, secret, SG)
#   - DataSync VPC endpoint (interface) + security group
#   - SSM Parameters con outputs del layer
#
# Nota: migración temporal (solo durante la migración). Se destruye al finalizar.
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
