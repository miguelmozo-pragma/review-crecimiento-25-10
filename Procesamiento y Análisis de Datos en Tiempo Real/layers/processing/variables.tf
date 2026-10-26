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
# Fraud Detector (recursos periféricos)
###############################################

variable "fraud_name" {
  type        = string
  description = "Funcionalidad de Fraud Detector (ej. fraude). Nombre final: rtda-{env}-fraud-{fraud_name}."
  default     = "fraude"
}

variable "fraud_create_training_bucket" {
  type        = bool
  description = "Crear el bucket S3 de datos de entrenamiento de Fraud Detector."
  default     = true
}

variable "fraud_force_destroy" {
  type        = bool
  description = "Permite destruir el bucket de entrenamiento aunque tenga objetos."
  default     = false
}

variable "fraud_lifecycle_rules" {
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
  description = "Reglas de ciclo de vida del bucket de entrenamiento."
  default     = []
}

variable "fraud_log_retention_in_days" {
  type        = number
  description = "Retención del log group de CloudWatch de Fraud Detector."
  default     = 30
}

###############################################
# Flink application
###############################################

variable "flink_application_name" {
  type        = string
  description = "Funcionalidad de la app Flink (ej. procesamiento). Nombre final: rtda-{env}-flink-{flink_application_name}."
  default     = "procesamiento"
}

variable "flink_runtime_environment" {
  type        = string
  description = "Versión del runtime de Apache Flink."
  default     = "FLINK-1_20"
}

variable "flink_code_object_key" {
  type        = string
  description = "Key del artefacto de código (jar/zip) de la app Flink dentro del bucket data lake."
  default     = "flink-code/app.zip"
}

variable "flink_start_application" {
  type        = bool
  description = "Si la app Flink debe iniciarse tras el despliegue. Poner false si el artefacto aún no existe."
  default     = false
}

variable "flink_parallelism" {
  type        = number
  description = "Paralelismo inicial de la app Flink."
  default     = 1
}

variable "flink_parallelism_per_kpu" {
  type        = number
  description = "Paralelismo por KPU."
  default     = 1
}

variable "flink_auto_scaling_enabled" {
  type        = bool
  description = "Habilita el auto-scaling de la app Flink."
  default     = true
}

variable "flink_log_level" {
  type        = string
  description = "Nivel de log de la app Flink."
  default     = "INFO"
}

variable "flink_metrics_level" {
  type        = string
  description = "Granularidad de métricas de la app Flink."
  default     = "APPLICATION"
}

variable "flink_log_retention_in_days" {
  type        = number
  description = "Retención del log group de CloudWatch de la app Flink."
  default     = 30
}

variable "flink_property_groups" {
  type = list(object({
    group_id     = string
    property_map = map(string)
  }))
  description = "Property groups de runtime pasados a la app Flink. Si se deja vacío, el layer inyecta un grupo por defecto con el stream y la región."
  default     = []
}
