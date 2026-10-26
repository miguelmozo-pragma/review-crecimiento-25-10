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
# Aurora PostgreSQL
###############################################

variable "aurora_cluster_name" {
  type        = string
  description = "Funcionalidad del cluster Aurora (nombre final: cb-{env}-aurora-{name})"
  default     = "core"
}

variable "aurora_engine_version" {
  type        = string
  description = "Versión del engine Aurora PostgreSQL"
  default     = "15.10"
}

variable "aurora_instance_class" {
  type        = string
  description = "Clase de instancia de Aurora (dimensionamiento por ambiente)"
  default     = "db.r6g.large"
}

variable "aurora_database_name" {
  type        = string
  description = "Nombre de la base de datos inicial"
  default     = "corebancario"
}

variable "aurora_create_read_replica" {
  type        = bool
  description = "Crear instancia reader además del writer (prod/qa)"
  default     = true
}

variable "aurora_deletion_protection" {
  type        = bool
  description = "Protección contra eliminación del cluster Aurora"
  default     = true
}

###############################################
# ElastiCache Redis
###############################################

variable "redis_name" {
  type        = string
  description = "Funcionalidad del Redis (nombre final: cb-{env}-elasticache-{name})"
  default     = "core"
}

variable "redis_engine_version" {
  type        = string
  description = "Versión del engine Redis"
  default     = "7.1"
}

variable "redis_node_type" {
  type        = string
  description = "Node type de ElastiCache (dimensionamiento por ambiente)"
  default     = "cache.r6g.large"
}

variable "redis_num_cache_clusters" {
  type        = number
  description = "Número total de nodos Redis (1 primary + N-1 replicas)"
  default     = 2
}

variable "redis_multi_az_enabled" {
  type        = bool
  description = "Habilitar Multi-AZ en Redis"
  default     = true
}

###############################################
# S3
###############################################

variable "s3_bucket_name" {
  type        = string
  description = "Funcionalidad del bucket S3 (nombre final: cb-{env}-s3-{name})"
  default     = "objetos"
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
