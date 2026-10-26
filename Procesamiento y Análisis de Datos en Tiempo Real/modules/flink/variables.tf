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
# Flink application
###############################################

variable "application_name" {
  type        = string
  description = "Functionality segment of the application name (e.g. procesamiento). Final name: rtda-{env}-flink-{application_name}."
}

variable "application_description" {
  type        = string
  description = "Description of the Flink application."
  default     = "RTDA real-time processing application (invokes Fraud Detector)."
}

variable "runtime_environment" {
  type        = string
  description = "Apache Flink runtime version (e.g. FLINK-1_20, FLINK-1_18)."
  default     = "FLINK-1_20"
  validation {
    condition     = can(regex("^FLINK-[0-9]+_[0-9]+$", var.runtime_environment))
    error_message = "runtime_environment must look like FLINK-1_20."
  }
}

variable "service_execution_role_arn" {
  type        = string
  description = "Existing IAM role ARN for the application when create_execution_role is false."
  default     = ""
}

variable "create_execution_role" {
  type        = bool
  description = "Whether to create a dedicated IAM execution role for the Flink application."
  default     = true
}

variable "start_application" {
  type        = bool
  description = "Whether the application should be started after deployment."
  default     = true
}

###############################################
# Code artifact (S3)
###############################################

variable "code_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket that stores the Flink application code artifact (jar/zip)."
}

variable "code_bucket_name" {
  type        = string
  description = "Name of the S3 bucket that stores the Flink application code artifact."
}

variable "code_object_key" {
  type        = string
  description = "S3 object key of the Flink application code artifact (jar/zip)."
}

variable "code_bucket_kms_key_arn" {
  type        = string
  description = "KMS key ARN protecting the code bucket, granted to the execution role. Empty string skips KMS permissions."
  default     = ""
}

###############################################
# Application runtime configuration
###############################################

variable "parallelism" {
  type        = number
  description = "Initial parallelism for the application."
  default     = 1
  validation {
    condition     = var.parallelism >= 1
    error_message = "parallelism must be at least 1."
  }
}

variable "parallelism_per_kpu" {
  type        = number
  description = "Parallelism per Kinesis Processing Unit (KPU)."
  default     = 1
}

variable "auto_scaling_enabled" {
  type        = bool
  description = "Whether automatic scaling of the application is enabled."
  default     = true
}

variable "checkpointing_enabled" {
  type        = bool
  description = "Whether checkpointing is enabled."
  default     = true
}

variable "checkpoint_interval" {
  type        = number
  description = "Checkpoint interval in milliseconds."
  default     = 60000
}

variable "min_pause_between_checkpoints" {
  type        = number
  description = "Minimum pause between checkpoints in milliseconds."
  default     = 5000
}

variable "log_level" {
  type        = string
  description = "Application log level."
  default     = "INFO"
  validation {
    condition     = contains(["ERROR", "WARN", "INFO", "DEBUG"], var.log_level)
    error_message = "log_level must be ERROR, WARN, INFO, or DEBUG."
  }
}

variable "metrics_level" {
  type        = string
  description = "Monitoring metrics granularity."
  default     = "APPLICATION"
  validation {
    condition     = contains(["APPLICATION", "TASK", "OPERATOR", "PARALLELISM"], var.metrics_level)
    error_message = "metrics_level must be APPLICATION, TASK, OPERATOR, or PARALLELISM."
  }
}

variable "property_groups" {
  type = list(object({
    group_id     = string
    property_map = map(string)
  }))
  description = "Runtime property groups passed to the Flink application (e.g. Kinesis stream name, Fraud Detector ids)."
  default     = []
}

###############################################
# IAM — resources the application needs to reach
###############################################

variable "kinesis_stream_arn" {
  type        = string
  description = "ARN of the source Kinesis Data Stream the application reads from."
}

variable "kinesis_stream_kms_key_arn" {
  type        = string
  description = "KMS key ARN of the source Kinesis stream, granted to the execution role for decrypt. Empty string skips."
  default     = ""
}

variable "fraud_detector_arns" {
  type        = list(string)
  description = "ARNs of the Fraud Detector resources the application is allowed to invoke (detector / outcomes). Empty list grants GetEventPrediction on all (documented checkov skip)."
  default     = []
}

variable "output_bucket_arns" {
  type        = list(string)
  description = "ARNs of S3 buckets the application writes processed output to (e.g. data lake). Bucket ARNs only; object ARNs are derived."
  default     = []
}

variable "output_bucket_kms_key_arns" {
  type        = list(string)
  description = "KMS key ARNs protecting the output buckets, granted to the execution role."
  default     = []
}

###############################################
# CloudWatch logging encryption
###############################################

variable "log_retention_in_days" {
  type        = number
  description = "Retention of the CloudWatch log group for the application."
  default     = 30
}

variable "create_cloudwatch_kms_key" {
  type        = bool
  description = "Whether to create a dedicated KMS CMK for the CloudWatch log group (with a key policy allowing the logs service)."
  default     = true
}

variable "cloudwatch_kms_key_arn" {
  type        = string
  description = "Existing KMS key ARN to encrypt the CloudWatch log group when create_cloudwatch_kms_key is false. Empty string uses default CloudWatch-managed encryption."
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
