###########################################
########## Common variables ###############
###########################################

variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment where resources will be deployed"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Must be dev, qa, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources will be deployed"
}

variable "bucket_name" {
  type        = string
  description = "Functional name for the bucket ({funcionalidad} segment), e.g. 'objetos'. Final name: cb-{env}-s3-{bucket_name}."
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.bucket_name))
    error_message = "bucket_name must contain only lowercase letters, numbers, and hyphens."
  }
}

###########################################
########## Encryption #####################
###########################################

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for SSE-KMS encryption. When null, a dedicated KMS key is created by this module."
  default     = null
}

variable "bucket_key_enabled" {
  type        = bool
  description = "Whether to use an S3 Bucket Key to reduce KMS costs."
  default     = true
}

###########################################
########## Versioning #####################
###########################################

variable "versioning_enabled" {
  type        = bool
  description = "Whether object versioning is enabled on the bucket."
  default     = true
}

###########################################
########## Lifecycle ######################
###########################################

variable "lifecycle_rules" {
  type = list(object({
    id                                     = string
    enabled                                = optional(bool, true)
    prefix                                 = optional(string, "")
    expiration_days                        = optional(number, null)
    noncurrent_version_expiration_days     = optional(number, null)
    abort_incomplete_multipart_upload_days = optional(number, 7)
    transition_days                        = optional(number, null)
    transition_storage_class               = optional(string, "STANDARD_IA")
  }))
  description = "Lifecycle rules for the bucket. Empty list disables lifecycle configuration."
  default     = []
}

###########################################
########## Access logging #################
###########################################

variable "logging_target_bucket" {
  type        = string
  description = "Target bucket name for S3 server access logs. When null, access logging is not configured."
  default     = null
}

variable "logging_target_prefix" {
  type        = string
  description = "Prefix for S3 server access log objects."
  default     = "s3-access-logs/"
}

###########################################
########## VPC endpoint policy ############
###########################################

variable "restrict_to_vpc_endpoint_id" {
  type        = string
  description = "When set, a bucket policy restricts access to the given S3 VPC endpoint ID (aws:sourceVpce). Null leaves no VPC-restriction policy."
  default     = null
}

variable "force_destroy" {
  type        = bool
  description = "Whether to allow Terraform to destroy a non-empty bucket."
  default     = false
}

###########################################
########## Additional Tags ################
###########################################

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources created by this module"
  default     = {}
}
