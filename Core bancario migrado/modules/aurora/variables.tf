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

###########################################
########## Cluster / identity #############
###########################################

variable "cluster_name" {
  type        = string
  description = "Functional name for the Aurora cluster ({funcionalidad} segment). Final name: cb-{env}-aurora-{cluster_name}."
  default     = "core"
}

variable "engine_version" {
  type        = string
  description = "Aurora PostgreSQL engine version."
  default     = "15.10"
}

variable "database_name" {
  type        = string
  description = "Name of the initial database created in the cluster."
  default     = "corebancario"
}

variable "master_username" {
  type        = string
  description = "Master username for the Aurora cluster."
  default     = "cbadmin"
}

variable "instance_class" {
  type        = string
  description = "Instance class for the Aurora cluster instances (writer and reader)."
  default     = "db.r6g.large"
}

###########################################
########## Networking #####################
###########################################

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the Aurora security group is created."
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the Aurora DB subnet group."
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID must be provided."
  }
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security group IDs allowed to reach Aurora on port 5432 (e.g. EKS nodes/pods security groups)."
  default     = []
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to reach Aurora on port 5432."
  default     = []
}

###########################################
########## Encryption #####################
###########################################

variable "kms_key_arn" {
  type        = string
  description = "ARN of an existing KMS CMK to encrypt the cluster and secret. When null, the module creates a dedicated KMS key."
  default     = null
}

###########################################
########## Behavior #######################
###########################################

variable "create_read_replica" {
  type        = bool
  description = "Whether to create a reader instance in addition to the writer."
  default     = false
}

variable "backup_retention_period" {
  type        = number
  description = "Number of days to retain automated backups."
  default     = 7
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Must be between 1 and 35 days."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Whether the cluster has deletion protection enabled."
  default     = true
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Whether to skip the final snapshot when the cluster is deleted."
  default     = true
}

variable "apply_immediately" {
  type        = bool
  description = "Whether modifications are applied immediately instead of during the maintenance window."
  default     = false
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Whether Performance Insights is enabled on the cluster instances."
  default     = true
}

###########################################
########## Additional Tags ################
###########################################

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources created by this module"
  default     = {}
}
