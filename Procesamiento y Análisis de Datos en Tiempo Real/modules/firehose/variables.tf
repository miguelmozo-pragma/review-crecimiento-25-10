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
# Firehose delivery stream
###############################################

variable "name" {
  type        = string
  description = "Functionality segment of the delivery stream name (e.g. raw). Final name: rtda-{env}-firehose-{name}."
}

variable "kinesis_stream_arn" {
  type        = string
  description = "ARN of the source Kinesis Data Stream."
}

variable "kinesis_stream_kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used to encrypt the source Kinesis stream (for decrypt permissions)."
}

###############################################
# S3 destination
###############################################

variable "destination_bucket_arn" {
  type        = string
  description = "ARN of the destination S3 bucket (raw data lake)."
}

variable "destination_kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used to encrypt objects in the destination S3 bucket."
}

variable "s3_prefix" {
  type        = string
  description = "Prefix for delivered objects."
  default     = "raw/"
}

variable "s3_error_output_prefix" {
  type        = string
  description = "Prefix for records that fail delivery."
  default     = "errors/"
}

variable "buffering_size" {
  type        = number
  description = "Buffer size in MB before delivering to S3 (1 to 128)."
  default     = 5
  validation {
    condition     = var.buffering_size >= 1 && var.buffering_size <= 128
    error_message = "buffering_size must be between 1 and 128 MB."
  }
}

variable "buffering_interval" {
  type        = number
  description = "Buffer interval in seconds before delivering to S3 (0 to 900)."
  default     = 300
  validation {
    condition     = var.buffering_interval >= 0 && var.buffering_interval <= 900
    error_message = "buffering_interval must be between 0 and 900 seconds."
  }
}

variable "compression_format" {
  type        = string
  description = "Compression for delivered objects."
  default     = "GZIP"
  validation {
    condition     = contains(["UNCOMPRESSED", "GZIP", "Snappy", "ZIP", "HADOOP_SNAPPY"], var.compression_format)
    error_message = "compression_format must be one of UNCOMPRESSED, GZIP, Snappy, ZIP, HADOOP_SNAPPY."
  }
}

###############################################
# CloudWatch logging
###############################################

variable "log_retention_in_days" {
  type        = number
  description = "Retention of the CloudWatch log group for the delivery stream."
  default     = 30
}

variable "create_cloudwatch_kms_key" {
  type        = bool
  description = "Whether to create a dedicated KMS CMK for the CloudWatch log group (with a key policy allowing the logs service). If false, cloudwatch_kms_key_arn is used (empty = default CloudWatch-managed encryption)."
  default     = true
}

variable "cloudwatch_kms_key_arn" {
  type        = string
  description = "Existing KMS key ARN to encrypt the CloudWatch log group when create_cloudwatch_kms_key is false. Empty string uses the default CloudWatch-managed encryption. The key policy must allow logs.{region}.amazonaws.com."
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
