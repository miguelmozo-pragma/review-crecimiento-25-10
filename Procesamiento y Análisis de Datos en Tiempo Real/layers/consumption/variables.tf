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
# SNS (notificación de fraude)
###############################################

variable "sns_topic_name" {
  type        = string
  description = "Funcionalidad del tópico SNS (ej. fraude). Nombre final: rtda-{env}-sns-{sns_topic_name}."
  default     = "fraude"
}

variable "sns_display_name" {
  type        = string
  description = "Display name del tópico SNS."
  default     = "RTDA Fraude"
}

variable "sns_subscriptions" {
  type = list(object({
    protocol             = string
    endpoint             = string
    raw_message_delivery = optional(bool, false)
    filter_policy        = optional(string, null)
  }))
  description = "Suscripciones al tópico (ej. email, https, sqs)."
  default     = []
}

###############################################
# Lambda (evento de fraude)
###############################################

variable "lambda_function_name" {
  type        = string
  description = "Funcionalidad de la Lambda (ej. evento-fraude). Nombre final: rtda-{env}-lambda-{lambda_function_name}."
  default     = "evento-fraude"
}

variable "lambda_description" {
  type        = string
  description = "Descripción de la Lambda."
  default     = "Genera un evento ante fraude y notifica vía SNS."
}

variable "lambda_runtime" {
  type        = string
  description = "Runtime de la Lambda."
  default     = "python3.12"
}

variable "lambda_handler" {
  type        = string
  description = "Entrypoint de la Lambda."
  default     = "app.lambda_handler"
}

variable "lambda_memory_size" {
  type        = number
  description = "Memoria (MB) de la Lambda."
  default     = 256
}

variable "lambda_timeout" {
  type        = number
  description = "Timeout (s) de la Lambda."
  default     = 30
}

variable "lambda_s3_bucket" {
  type        = string
  description = "Bucket S3 con el paquete de despliegue de la Lambda. Null usa un placeholder local."
  default     = null
}

variable "lambda_s3_key" {
  type        = string
  description = "Key S3 del paquete de despliegue de la Lambda."
  default     = null
}

variable "lambda_log_retention_days" {
  type        = number
  description = "Retención de logs de la Lambda."
  default     = 30
}

variable "lambda_reserved_concurrency" {
  type        = number
  description = "Concurrencia reservada de la Lambda. -1 sin reservar."
  default     = -1
}

variable "lambda_environment_variables" {
  type        = map(string)
  description = "Variables de entorno adicionales de la Lambda (se combinan con las inyectadas por el layer)."
  default     = {}
}

variable "lambda_read_from_stream" {
  type        = bool
  description = "Conceder a la Lambda permisos de lectura sobre el Kinesis stream de procesamiento."
  default     = true
}
