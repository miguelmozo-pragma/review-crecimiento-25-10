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

variable "name" {
  type        = string
  description = "Functional name for the DMS resources ({funcionalidad} segment), e.g. 'core'. Final name: cb-{env}-dms-{name}."
  default     = "core"
}

variable "create_dms_vpc_role" {
  type        = bool
  description = "Create the account-level 'dms-vpc-role' service role required by DMS to manage VPC resources. Set to false if it already exists in the account (it is a shared, account-wide role)."
  default     = true
}

###########################################
########## Networking #####################
###########################################

variable "vpc_id" {
  type        = string
  description = "VPC ID where the DMS replication instance security group is created."
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the DMS replication subnet group."
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "DMS requires at least two subnets in different AZs."
  }
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks the DMS instance is allowed to reach / be reached from (e.g. on-prem source and target DB ranges)."
  default     = []
}

###########################################
########## Replication instance ###########
###########################################

variable "replication_instance_class" {
  type        = string
  description = "DMS replication instance class (sizing per environment)."
  default     = "dms.t3.medium"
}

variable "allocated_storage" {
  type        = number
  description = "Amount of storage (GB) for the replication instance."
  default     = 50
}

variable "engine_version" {
  type        = string
  description = "DMS engine version."
  default     = "3.5.4"
}

variable "multi_az" {
  type        = bool
  description = "Whether the replication instance is Multi-AZ."
  default     = false
}

variable "publicly_accessible" {
  type        = bool
  description = "Whether the replication instance is publicly accessible."
  default     = false
}

###########################################
########## KMS ############################
###########################################

variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN for DMS and secret encryption. When null, a dedicated CMK is created by this module."
  default     = null
}

###########################################
########## Source endpoint (on-prem) ######
###########################################

variable "source_engine_name" {
  type        = string
  description = "Engine name of the source endpoint."
  default     = "postgres"
}

variable "source_server_name" {
  type        = string
  description = "Hostname/IP of the source database server (on-prem PostgreSQL)."
}

variable "source_port" {
  type        = number
  description = "Port of the source database."
  default     = 5432
}

variable "source_database_name" {
  type        = string
  description = "Database name on the source endpoint."
}

variable "source_username" {
  type        = string
  description = "Username for the source database connection."
}

variable "source_password" {
  type        = string
  description = "Password for the source database connection. Stored in Secrets Manager."
  sensitive   = true
}

###########################################
########## Target endpoint (Aurora) #######
###########################################

variable "target_engine_name" {
  type        = string
  description = "Engine name of the target endpoint."
  default     = "aurora-postgresql"
}

variable "target_server_name" {
  type        = string
  description = "Hostname of the target database (Aurora writer endpoint)."
}

variable "target_port" {
  type        = number
  description = "Port of the target database."
  default     = 5432
}

variable "target_database_name" {
  type        = string
  description = "Database name on the target endpoint."
}

variable "target_username" {
  type        = string
  description = "Username for the target database connection."
}

variable "target_password" {
  type        = string
  description = "Password for the target database connection. Stored in Secrets Manager."
  sensitive   = true
}

###########################################
########## Replication task ###############
###########################################

variable "migration_type" {
  type        = string
  description = "DMS migration type: full-load, cdc, or full-load-and-cdc."
  default     = "full-load-and-cdc"
  validation {
    condition     = contains(["full-load", "cdc", "full-load-and-cdc"], var.migration_type)
    error_message = "Must be full-load, cdc, or full-load-and-cdc."
  }
}

variable "table_mappings" {
  type        = string
  description = "JSON string with the DMS table mappings. Defaults to migrating all tables."
  default     = null
}

variable "start_replication_task" {
  type        = bool
  description = "Whether Terraform starts the replication task on creation."
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
