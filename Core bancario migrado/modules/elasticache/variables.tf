###########################################
# Common variables
###########################################

variable "project" {
  type        = string
  description = "Project / workload code (always 'cb' for Core Bancario)."
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, qa, prod)."
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Must be dev, qa, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region where the ElastiCache resources are deployed."
}

###########################################
# Identity / networking
###########################################

variable "name" {
  type        = string
  default     = "core"
  description = "Functionality segment ({funcionalidad}) for naming, e.g. 'core'. Lowercase letters, digits and hyphens; must keep the composed replication_group_id <= 40 chars."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "name must start with a lowercase letter and contain only lowercase letters, digits, and hyphens."
  }
  validation {
    condition     = length("cb-prod-elasticache-${var.name}") <= 40
    error_message = "name too long: composed replication_group_id 'cb-{env}-elasticache-{name}' must be <= 40 chars (prod has the longest prefix)."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC id where the Redis security group is created."
  validation {
    condition     = can(regex("^vpc-", var.vpc_id))
    error_message = "vpc_id must be a valid VPC id (vpc-...)."
  }
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet ids for the ElastiCache subnet group."
  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "subnet_ids must contain at least one private subnet id."
  }
}

###########################################
# Access control
###########################################

variable "allowed_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security group ids allowed to reach Redis on port 6379."
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "CIDR blocks allowed to reach Redis on port 6379."
  validation {
    condition     = alltrue([for c in var.allowed_cidr_blocks : can(cidrhost(c, 0))])
    error_message = "allowed_cidr_blocks must be valid CIDR blocks."
  }
}

###########################################
# KMS
###########################################

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "KMS CMK ARN for encryption at rest. When null, a dedicated CMK is created by this module."
}

###########################################
# Engine / sizing
###########################################

variable "engine_version" {
  type        = string
  default     = "7.1"
  description = "Redis engine version (e.g. '7.1')."
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9x]+$", var.engine_version))
    error_message = "engine_version must look like '7.1' or '6.x'."
  }
}

variable "node_type" {
  type        = string
  default     = "cache.r6g.large"
  description = "ElastiCache node type (cache.* instance class)."
  validation {
    condition     = can(regex("^cache\\.", var.node_type))
    error_message = "node_type must be a valid ElastiCache node type (cache.*)."
  }
}

variable "num_cache_clusters" {
  type        = number
  default     = 2
  description = "Total nodes for the cluster-mode-disabled replication group (1 primary + (N-1) replicas). Between 1 and 6."
  validation {
    condition     = var.num_cache_clusters >= 1 && var.num_cache_clusters <= 6
    error_message = "num_cache_clusters must be between 1 and 6 (cluster-mode-disabled)."
  }
}

variable "automatic_failover_enabled" {
  type        = bool
  default     = true
  description = "Enable automatic failover. Effectively clamped to false when num_cache_clusters == 1 (single node) via locals."
}

variable "multi_az_enabled" {
  type        = bool
  default     = true
  description = "Enable Multi-AZ. Effectively clamped to false when automatic failover is off (single node) via locals."
}

variable "snapshot_retention_limit" {
  type        = number
  default     = 5
  description = "Days to retain automatic snapshots (0 disables snapshots)."
  validation {
    condition     = var.snapshot_retention_limit >= 0 && var.snapshot_retention_limit <= 35
    error_message = "snapshot_retention_limit must be between 0 and 35."
  }
}

variable "maintenance_window" {
  type        = string
  default     = "sun:05:00-sun:07:00"
  description = "Weekly maintenance window (ddd:hh24:mi-ddd:hh24:mi)."
}

variable "apply_immediately" {
  type        = bool
  default     = false
  description = "Apply modifications immediately instead of during the maintenance window."
}

###########################################
# Auth
###########################################

variable "auth_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "Redis AUTH token. When set, requires transit encryption (always enabled by this module). Recommended for prod. Left null when unset. 16-128 chars when set."
  validation {
    condition     = var.auth_token == null ? true : (length(var.auth_token) >= 16 && length(var.auth_token) <= 128)
    error_message = "auth_token must be 16-128 chars when set."
  }
}

###########################################
# Tags
###########################################

variable "additional_tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags merged into every resource."
}
