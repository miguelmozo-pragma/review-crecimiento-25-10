###############################################
# Variables comunes (obligatorias)
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

variable "common_tags" {
  description = "Tags corporativos obligatorios para todos los recursos"
  type        = map(string)
  default = {
    Ambiente    = ""
    Proyecto    = ""
    Descripcion = ""
  }
}

###############################################
# Bucket RAW (destino de Firehose)
###############################################

variable "raw_bucket_name" {
  type        = string
  description = "Funcionalidad del bucket raw (ej. raw). Nombre final: rtda-{env}-s3-{raw_bucket_name}."
  default     = "raw"
}

variable "raw_force_destroy" {
  type        = bool
  description = "Permite destruir el bucket raw aunque tenga objetos."
  default     = false
}

variable "raw_versioning_enabled" {
  type        = bool
  description = "Habilita versionamiento en el bucket raw."
  default     = true
}

variable "raw_lifecycle_rules" {
  type = list(object({
    id                                 = string
    enabled                            = bool
    prefix                             = string
    expiration_days                    = number
    noncurrent_version_expiration_days = number
    transition = list(object({
      days          = number
      storage_class = string
    }))
  }))
  description = "Reglas de ciclo de vida del bucket raw (transición a clases frías / expiración)."
  default     = []
}

###############################################
# Bucket DATA LAKE (consumo analítico)
###############################################

variable "datalake_bucket_name" {
  type        = string
  description = "Funcionalidad del bucket data lake (ej. datalake). Nombre final: rtda-{env}-s3-{datalake_bucket_name}."
  default     = "datalake"
}

variable "datalake_force_destroy" {
  type        = bool
  description = "Permite destruir el bucket data lake aunque tenga objetos."
  default     = false
}

variable "datalake_versioning_enabled" {
  type        = bool
  description = "Habilita versionamiento en el bucket data lake."
  default     = true
}

variable "datalake_lifecycle_rules" {
  type = list(object({
    id                                 = string
    enabled                            = bool
    prefix                             = string
    expiration_days                    = number
    noncurrent_version_expiration_days = number
    transition = list(object({
      days          = number
      storage_class = string
    }))
  }))
  description = "Reglas de ciclo de vida del bucket data lake."
  default     = []
}

###############################################
# Lake Formation
###############################################

variable "database_name" {
  type        = string
  description = "Funcionalidad de la base de datos del catálogo (ej. datalake). Nombre final: rtda-{env}-lakeformation-{database_name}."
  default     = "datalake"
}

variable "database_description" {
  type        = string
  description = "Descripción de la base de datos del Glue Data Catalog."
  default     = "RTDA data lake database governed by Lake Formation."
}

variable "manage_data_lake_settings" {
  type        = bool
  description = "Si este layer gestiona el recurso global de data lake settings de la cuenta."
  default     = false
}

variable "data_lake_admins" {
  type        = list(string)
  description = "ARNs de los principales IAM que serán administradores del data lake en Lake Formation."
  default     = []
}

variable "use_service_linked_role" {
  type        = bool
  description = "Registrar la ubicación S3 con el service-linked role de Lake Formation en vez de un rol dedicado."
  default     = false
}

variable "database_permissions" {
  type = list(object({
    principal                  = string
    permissions                = list(string)
    permissions_with_grant_opt = optional(list(string), [])
  }))
  description = "Permisos de grano fino a nivel database concedidos a principales autorizados."
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
  description = "Permisos de grano fino a nivel tabla concedidos a principales autorizados."
  default     = []
}
