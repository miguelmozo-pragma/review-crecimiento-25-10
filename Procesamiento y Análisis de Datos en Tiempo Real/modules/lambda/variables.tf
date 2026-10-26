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
# Lambda function
###############################################

variable "function_name" {
  type        = string
  description = "Functionality segment (e.g. evento-fraude). Final name: rtda-{env}-lambda-{function_name}."
}

variable "description" {
  type        = string
  description = "Description of the Lambda function."
  default     = ""
}

variable "runtime" {
  type        = string
  description = "Lambda runtime (e.g. nodejs20.x, python3.12, java21)."
  default     = "python3.12"
}

variable "handler" {
  type        = string
  description = "Function entrypoint (e.g. index.handler, app.lambda_handler)."
  default     = "app.lambda_handler"
}

variable "memory_size" {
  type        = number
  description = "Memory in MB allocated to the function."
  default     = 256
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  type        = number
  description = "Function timeout in seconds."
  default     = 30
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Must be between 1 and 900 seconds."
  }
}

variable "architectures" {
  type        = list(string)
  description = "Instruction set architecture for the function."
  default     = ["arm64"]
  validation {
    condition     = length(var.architectures) == 1 && contains(["x86_64", "arm64"], var.architectures[0])
    error_message = "Must be [\"x86_64\"] or [\"arm64\"]."
  }
}

###############################################
# Packaging
###############################################

variable "package_type" {
  type        = string
  description = "Lambda deployment package type."
  default     = "Zip"
  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "Must be Zip or Image."
  }
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket containing the deployment package (Zip type)."
  default     = null
}

variable "s3_key" {
  type        = string
  description = "S3 key of the deployment package (Zip type)."
  default     = null
}

variable "image_uri" {
  type        = string
  description = "ECR image URI (Image package type)."
  default     = null
}

variable "filename" {
  type        = string
  description = "Path to a local deployment package (initial placeholder deployment)."
  default     = null
}

###############################################
# Networking (optional VPC)
###############################################

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for VPC configuration. Empty means the function runs without VPC."
  default     = []
}

variable "vpc_security_group_ids" {
  type        = list(string)
  description = "Security group IDs for VPC configuration."
  default     = []
}

###############################################
# Environment variables
###############################################

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables for the function."
  default     = {}
}

###############################################
# IAM
###############################################

variable "create_role" {
  type        = bool
  description = "Whether to create a dedicated IAM role or use an existing one."
  default     = true
}

variable "existing_role_arn" {
  type        = string
  description = "ARN of an existing IAM role (when create_role = false)."
  default     = null
}

variable "policy_statements" {
  type = list(object({
    sid       = string
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  description = "Additional IAM policy statements attached to the Lambda role (e.g. publish to SNS, read from the stream)."
  default     = []
}

###############################################
# Encryption
###############################################

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN to encrypt environment variables. If null, uses the AWS managed key."
  default     = null
}

variable "create_cloudwatch_kms_key" {
  type        = bool
  description = "Whether to create a dedicated KMS CMK for the CloudWatch log group."
  default     = true
}

variable "cloudwatch_log_kms_key_arn" {
  type        = string
  description = "Existing KMS key ARN to encrypt the log group when create_cloudwatch_kms_key is false. Empty string uses default encryption."
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

###############################################
# Logging
###############################################

variable "log_retention_days" {
  type        = number
  description = "Days to retain CloudWatch logs."
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Must be a valid CloudWatch Logs retention value."
  }
}

###############################################
# Concurrency / DLQ / Layers / Tracing
###############################################

variable "reserved_concurrent_executions" {
  type        = number
  description = "Reserved concurrent executions. Use -1 for unreserved."
  default     = -1
  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "Must be -1 (unreserved) or >= 0."
  }
}

variable "dead_letter_target_arn" {
  type        = string
  description = "ARN of an SQS queue or SNS topic for the dead letter queue. Null disables DLQ."
  default     = null
}

variable "layers" {
  type        = list(string)
  description = "Lambda layer ARNs to attach."
  default     = []
}

variable "tracing_mode" {
  type        = string
  description = "X-Ray tracing mode."
  default     = "PassThrough"
  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "Must be Active or PassThrough."
  }
}

###############################################
# CloudWatch alarm
###############################################

variable "create_alarm" {
  type        = bool
  description = "Whether to create a CloudWatch alarm for Lambda errors."
  default     = true
}

variable "alarm_evaluation_periods" {
  type        = number
  description = "Number of periods to evaluate the alarm."
  default     = 1
  validation {
    condition     = var.alarm_evaluation_periods >= 1
    error_message = "Must be at least 1."
  }
}

variable "alarm_period" {
  type        = number
  description = "Period in seconds for the alarm evaluation."
  default     = 300
  validation {
    condition     = contains([60, 120, 180, 300, 600, 900], var.alarm_period)
    error_message = "Must be 60, 120, 180, 300, 600, or 900."
  }
}

variable "alarm_error_threshold" {
  type        = number
  description = "Number of errors to trigger the alarm."
  default     = 1
  validation {
    condition     = var.alarm_error_threshold >= 1
    error_message = "Must be at least 1."
  }
}

variable "alarm_actions" {
  type        = list(string)
  description = "ARNs to notify when the alarm triggers (e.g. SNS topic ARNs)."
  default     = []
}
