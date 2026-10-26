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
# Kinesis Data Stream
###############################################

variable "stream_name" {
  type        = string
  description = "Functionality segment of the stream name (e.g. ingesta). Final name: rtda-{env}-kinesis-{stream_name}."
}

variable "stream_mode" {
  type        = string
  description = "Kinesis capacity mode: ON_DEMAND or PROVISIONED."
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "PROVISIONED"], var.stream_mode)
    error_message = "stream_mode must be ON_DEMAND or PROVISIONED."
  }
}

variable "shard_count" {
  type        = number
  description = "Number of shards. Only used when stream_mode is PROVISIONED."
  default     = null

  validation {
    condition     = var.shard_count == null || try(var.shard_count >= 1, false)
    error_message = "shard_count must be null (ON_DEMAND) or a positive integer (PROVISIONED)."
  }
}

variable "retention_period" {
  type        = number
  description = "Data retention period in hours (24 to 8760)."
  default     = 24
  validation {
    condition     = var.retention_period >= 24 && var.retention_period <= 8760
    error_message = "retention_period must be between 24 and 8760 hours."
  }
}

variable "shard_level_metrics" {
  type        = list(string)
  description = "Enhanced shard-level CloudWatch metrics to enable."
  default     = ["IncomingBytes", "OutgoingBytes", "IncomingRecords", "OutgoingRecords"]
}

###############################################
# KMS encryption
###############################################

variable "create_kms_key" {
  type        = bool
  description = "Whether to create a dedicated KMS CMK for the stream. If false, kms_key_arn must be provided."
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
