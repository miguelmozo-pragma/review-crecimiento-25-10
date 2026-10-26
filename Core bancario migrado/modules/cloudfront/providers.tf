###########################################
# Version definition - Terraform - Providers
###########################################

terraform {
  required_providers {
    aws = {
      configuration_aliases = [aws.project]
      source                = "hashicorp/aws"
      version               = ">= 5.68.0"
    }
  }
}
