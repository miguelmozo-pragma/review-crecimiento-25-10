###############################################
# Module: Fraud Detector (peripheral resources)
#
# NOTE: The AWS Terraform provider does NOT support native
# aws_frauddetector_* resources. This module manages only the peripheral
# resources Fraud Detector needs (dedicated CMK, training-data S3 bucket,
# service role, CloudWatch). The detector itself (variables, labels,
# eventType, outcomes, rules, models) is managed outside Terraform.
#
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
