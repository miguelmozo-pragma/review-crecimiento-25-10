###############################################
# Common variables
###############################################

variable "project" {
  type        = string
  description = "Project / workload name (e.g. rtda)."
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Must be dev, qa, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources will be deployed."
}

variable "additional_tags" {
  type        = map(string)
  description = "Extra corporate tags propagated to every resource."
  default     = {}
}

###############################################
# Naming
###############################################

variable "name" {
  type        = string
  description = "Functionality segment (e.g. fraude). Used for bucket, role, keys and logs: rtda-{env}-fraud-{name}."
  default     = "fraude"
}

variable "resource_suffix" {
  type        = string
  description = "Regional suffix for globally-unique S3 names. Empty by default, e.g. -us-west-2."
  default     = ""
}

###############################################
# Training-data S3 bucket (create-or-skip)
###############################################

variable "create_training_bucket" {
  type        = bool
  description = "Whether to create the S3 bucket that stores Fraud Detector training data."
  default     = true
}

variable "force_destroy" {
  type        = bool
  description = "Whether to force destroy the training bucket even if it contains objects."
  default     = false
}

variable "versioning_enabled" {
  type        = bool
  description = "Whether to enable versioning on the training bucket."
  default     = true
}

variable "lifecycle_rules" {
  type = list(object({
    id                                 = string
    enabled                            = bool
    prefix                             = string
    expiration_days                    = number
    noncurrent_version_expiration_days = number
    transition = list(object({
      days          = number
      storage_class = string
    }))
  }))
  description = "Lifecycle rules for the training bucket."
  default     = []
}

###############################################
# Data encryption (dedicated CMK)
###############################################

variable "create_kms_key" {
  type        = bool
  description = "Whether to create a dedicated KMS CMK for Fraud Detector data. If false, kms_key_arn must be provided."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "Existing KMS key ARN to use when create_kms_key is false."
  default     = ""
}

variable "kms_deletion_window_in_days" {
  type        = number
  description = "Waiting period before the data CMK is deleted."
  default     = 30
  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

###############################################
# Service role (create-or-skip)
###############################################

variable "create_service_role" {
  type        = bool
  description = "Whether to create the IAM service role assumed by Fraud Detector."
  default     = true
}

###############################################
# CloudWatch logging
###############################################

variable "create_log_group" {
  type        = bool
  description = "Whether to create a CloudWatch log group for Fraud Detector operations."
  default     = true
}

variable "log_retention_in_days" {
  type        = number
  description = "Retention of the CloudWatch log group."
  default     = 30
}

variable "create_cloudwatch_kms_key" {
  type        = bool
  description = "Whether to create a dedicated KMS CMK for the CloudWatch log group."
  default     = true
}

variable "cloudwatch_kms_key_arn" {
  type        = string
  description = "Existing KMS key ARN to encrypt the CloudWatch log group when create_cloudwatch_kms_key is false. Empty string uses default encryption."
  default     = ""
}

variable "cloudwatch_kms_deletion_window_in_days" {
  type        = number
  description = "Waiting period before the CloudWatch Logs CMK is deleted."
  default     = 30
  validation {
    condition     = var.cloudwatch_kms_deletion_window_in_days >= 7 && var.cloudwatch_kms_deletion_window_in_days <= 30
    error_message = "cloudwatch_kms_deletion_window_in_days must be between 7 and 30."
  }
}
