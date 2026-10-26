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
# Data Lake settings administrators
###############################################

variable "data_lake_admins" {
  type        = list(string)
  description = "List of IAM principal ARNs to set as Lake Formation data lake administrators. Empty list leaves the current admins unchanged (Terraform does not manage the settings resource)."
  default     = []
}

variable "manage_data_lake_settings" {
  type        = bool
  description = "Whether this module manages aws_lakeformation_data_lake_settings. Only one module/layer in the account should own this global resource."
  default     = false
}

###############################################
# S3 location registration
###############################################

variable "s3_location_arn" {
  type        = string
  description = "ARN of the S3 location (bucket or prefix) to register in Lake Formation as a data lake location."
}

variable "create_registration_role" {
  type        = bool
  description = "Whether to create a dedicated IAM role for Lake Formation to access the registered S3 location. If false and registration_role_arn is empty, the AWS service-linked role is used."
  default     = true
}

variable "registration_role_arn" {
  type        = string
  description = "Existing IAM role ARN for the registered S3 location when create_registration_role is false."
  default     = ""
}

variable "s3_location_kms_key_arn" {
  type        = string
  description = "KMS key ARN protecting the registered S3 location, granted to the registration role for decrypt/encrypt. Empty string skips KMS permissions."
  default     = ""
}

variable "use_service_linked_role" {
  type        = bool
  description = "Register the S3 location using the Lake Formation service-linked role instead of a custom role. When true, create_registration_role should be false."
  default     = false
}

###############################################
# Glue Data Catalog database
###############################################

variable "database_name" {
  type        = string
  description = "Functionality segment of the database name (e.g. datalake). Final name: rtda-{env}-lakeformation-{database_name}."
}

variable "database_description" {
  type        = string
  description = "Description of the Glue Data Catalog database."
  default     = "RTDA data lake database governed by Lake Formation."
}

variable "database_location_uri" {
  type        = string
  description = "S3 URI used as the default location for the database (e.g. s3://rtda-dev-s3-datalake/)."
  default     = ""
}

###############################################
# Glue Data Catalog tables (optional)
###############################################

variable "tables" {
  type = list(object({
    name           = string
    description    = optional(string, "")
    location       = string
    input_format   = optional(string, "org.apache.hadoop.mapred.TextInputFormat")
    output_format  = optional(string, "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat")
    ser_de_name    = optional(string, "parquet")
    ser_de_library = optional(string, "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe")
    table_type     = optional(string, "EXTERNAL_TABLE")
    columns = list(object({
      name    = string
      type    = string
      comment = optional(string, "")
    }))
    partition_keys = optional(list(object({
      name    = string
      type    = string
      comment = optional(string, "")
    })), [])
  }))
  description = "Glue Data Catalog tables to create inside the database."
  default     = []
}

###############################################
# Lake Formation fine-grained permissions
###############################################

variable "database_permissions" {
  type = list(object({
    principal                  = string
    permissions                = list(string)
    permissions_with_grant_opt = optional(list(string), [])
  }))
  description = "Database-level Lake Formation permissions granted to principals (least privilege)."
  default     = []
}

variable "table_permissions" {
  type = list(object({
    principal                  = string
    table                      = string
    wildcard                   = optional(bool, false)
    permissions                = list(string)
    permissions_with_grant_opt = optional(list(string), [])
  }))
  description = "Table-level Lake Formation permissions granted to principals. Set wildcard=true to target all tables in the database."
  default     = []
}
