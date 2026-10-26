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
# Kinesis Data Stream
###############################################

variable "stream_name" {
  type        = string
  description = "Funcionalidad del stream (ej. ingesta). Nombre final: rtda-{env}-kinesis-{stream_name}."
  default     = "ingesta"
}

variable "stream_mode" {
  type        = string
  description = "Modo de capacidad del stream: ON_DEMAND o PROVISIONED."
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "PROVISIONED"], var.stream_mode)
    error_message = "stream_mode debe ser ON_DEMAND o PROVISIONED."
  }
}

variable "shard_count" {
  type        = number
  description = "Número de shards (solo aplica en modo PROVISIONED)."
  default     = null
}

variable "retention_period" {
  type        = number
  description = "Retención de datos en horas (24 a 8760)."
  default     = 24
}

variable "shard_level_metrics" {
  type        = list(string)
  description = "Métricas enhanced de nivel shard a habilitar."
  default     = ["IncomingBytes", "OutgoingBytes", "IncomingRecords", "OutgoingRecords"]
}

variable "kinesis_kms_deletion_window_in_days" {
  type        = number
  description = "Ventana de espera antes de eliminar la CMK de Kinesis."
  default     = 30
}

###############################################
# Firehose delivery stream
###############################################

variable "firehose_name" {
  type        = string
  description = "Funcionalidad del delivery stream (ej. raw). Nombre final: rtda-{env}-firehose-{firehose_name}."
  default     = "raw"
}

variable "s3_prefix" {
  type        = string
  description = "Prefijo de los objetos entregados en S3."
  default     = "raw/"
}

variable "s3_error_output_prefix" {
  type        = string
  description = "Prefijo para registros que fallan la entrega."
  default     = "errors/"
}

variable "buffering_size" {
  type        = number
  description = "Tamaño del buffer en MB antes de entregar a S3 (1 a 128)."
  default     = 5
}

variable "buffering_interval" {
  type        = number
  description = "Intervalo del buffer en segundos antes de entregar a S3 (0 a 900)."
  default     = 300
}

variable "compression_format" {
  type        = string
  description = "Compresión de los objetos entregados."
  default     = "GZIP"
}

variable "firehose_log_retention_in_days" {
  type        = number
  description = "Retención del log group de CloudWatch del delivery stream."
  default     = 30
}
