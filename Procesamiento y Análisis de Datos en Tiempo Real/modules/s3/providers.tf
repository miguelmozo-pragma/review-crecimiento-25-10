###############################################
# Module: S3 Bucket
#
# Required providers declaration.
# Backend is NOT declared here (only at the layer level).
###############################################

terraform {
  required_providers {
    aws = {
      configuration_aliases = [aws.project]
      source                = "hashicorp/aws"
      version               = ">= 5.0.0"
    }
  }
}
