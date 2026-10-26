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
# Bucket
###############################################

variable "bucket_name" {
  type        = string
  description = "Functionality segment of the bucket name (e.g. raw, datalake). Final name: rtda-{env}-s3-{bucket_name}."
}

variable "resource_suffix" {
  type        = string
  description = "Regional suffix for globally-unique S3 names. Empty by default, e.g. -us-west-2."
  default     = ""
}

variable "force_destroy" {
  type        = bool
  description = "Whether to force destroy the bucket even if it contains objects."
  default     = false
}

variable "versioning_enabled" {
  type        = bool
  description = "Whether to enable versioning on the bucket."
  default     = true
}

###############################################
# Encryption (SSE-KMS mandatory)
###############################################

variable "create_kms_key" {
  type        = bool
  description = "Whether to create a dedicated KMS CMK for this bucket. If false, kms_key_arn must be provided."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "Existing KMS key ARN to use when create_kms_key is false."
  default     = ""
}

variable "kms_deletion_window_in_days" {
  type        = number
  description = "Waiting period before the KMS key is deleted."
  default     = 30
  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

###############################################
# Lifecycle
###############################################

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
  description = "List of lifecycle rules for the bucket."
  default     = []
}

###############################################
# Public access (blocked by default)
###############################################

variable "block_public_acls" {
  type        = bool
  description = "Whether to block public ACLs."
  default     = true
}

variable "block_public_policy" {
  type        = bool
  description = "Whether to block public bucket policies."
  default     = true
}

variable "ignore_public_acls" {
  type        = bool
  description = "Whether to ignore public ACLs."
  default     = true
}

variable "restrict_public_buckets" {
  type        = bool
  description = "Whether to restrict public bucket policies."
  default     = true
}

###############################################
# Bucket policy
###############################################

variable "bucket_policy" {
  type        = string
  description = "Custom bucket policy JSON. If null, no policy is attached."
  default     = null
}
