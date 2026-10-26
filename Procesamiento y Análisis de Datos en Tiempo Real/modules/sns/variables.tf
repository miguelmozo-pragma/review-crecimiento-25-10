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
# SNS topic
###############################################

variable "topic_name" {
  type        = string
  description = "Functionality segment (e.g. fraude). Final name: rtda-{env}-sns-{topic_name}."
}

variable "display_name" {
  type        = string
  description = "Display name of the topic (used in SMS and email subjects)."
  default     = ""
}

variable "fifo_topic" {
  type        = bool
  description = "Whether the topic is a FIFO topic."
  default     = false
}

###############################################
# Encryption (dedicated CMK)
###############################################

variable "create_kms_key" {
  type        = bool
  description = "Whether to create a dedicated KMS CMK for the topic. If false, kms_key_id must be provided."
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "Existing KMS key id/ARN to use when create_kms_key is false."
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
# Access policy
###############################################

variable "topic_policy" {
  type        = string
  description = "Custom SNS topic access policy JSON. If null, the default AWS-managed policy applies."
  default     = null
}

variable "allowed_publisher_arns" {
  type        = list(string)
  description = "IAM principal ARNs allowed to publish to the topic. Used to build a least-privilege policy when topic_policy is null and this list is non-empty."
  default     = []
}

###############################################
# Subscriptions
###############################################

variable "subscriptions" {
  type = list(object({
    protocol             = string
    endpoint             = string
    raw_message_delivery = optional(bool, false)
    filter_policy        = optional(string, null)
  }))
  description = "List of subscriptions to the topic (e.g. email, sqs, lambda, https)."
  default     = []
}
