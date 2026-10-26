###############################################
# Variables generales
###############################################

variable "project" {
  type        = string
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "El ambiente debe ser 'dev', 'qa' o 'prod'."
  }
}

variable "region" {
  type        = string
  description = "Región AWS de despliegue"
}

variable "profile" {
  type        = string
  default     = ""
  description = "AWS CLI profile (vacío usa default credential chain)"
}

###############################################
# DMS
###############################################

variable "dms_name" {
  type        = string
  description = "Funcionalidad de los recursos DMS (nombre final: cb-{env}-dms-{name})"
  default     = "core"
}

variable "dms_replication_instance_class" {
  type        = string
  description = "Clase de la replication instance de DMS (dimensionamiento por ambiente)"
  default     = "dms.t3.medium"
}

variable "dms_engine_version" {
  type        = string
  description = "Versión del engine de DMS"
  default     = "3.5.4"
}

variable "dms_migration_type" {
  type        = string
  description = "Tipo de migración DMS (full-load, cdc, full-load-and-cdc)"
  default     = "full-load-and-cdc"
}

# ---- Source (PostgreSQL on-prem) ----
variable "dms_source_server_name" {
  type        = string
  description = "Host/IP del servidor PostgreSQL on-prem (origen)"
}

variable "dms_source_database_name" {
  type        = string
  description = "Nombre de la base de datos origen"
}

variable "dms_source_username" {
  type        = string
  description = "Usuario de conexión al origen"
}

variable "dms_source_password" {
  type        = string
  description = "Password de conexión al origen (inyectar vía -var o TF_VAR_, NO en tfvars)"
  sensitive   = true
}

# ---- Target (Aurora) ----
variable "dms_target_server_name" {
  type        = string
  description = "Host del Aurora writer endpoint (destino)"
}

variable "dms_target_database_name" {
  type        = string
  description = "Nombre de la base de datos destino"
}

variable "dms_target_username" {
  type        = string
  description = "Usuario de conexión al destino"
}

variable "dms_target_password" {
  type        = string
  description = "Password de conexión al destino (inyectar vía -var o TF_VAR_, NO en tfvars)"
  sensitive   = true
}

###############################################
# DataSync VPC endpoint
###############################################

variable "datasync_name" {
  type        = string
  description = "Funcionalidad del endpoint DataSync (nombre final: cb-{env}-datasync-{name})"
  default     = "core"
}

###############################################
# Variables Tags
###############################################

variable "common_tags" {
  description = "Tags corporativos obligatorios para todos los recursos"
  type        = map(string)
  default = {
    Ambiente    = ""
    Proyecto    = ""
    Descripcion = ""
  }
}
