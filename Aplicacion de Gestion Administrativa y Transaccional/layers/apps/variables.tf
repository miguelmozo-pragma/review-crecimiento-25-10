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
# EKS
###############################################

variable "cluster_name" {
  type        = string
  description = "Funcionalidad del cluster EKS (nombre final: cb-{env}-eks-{cluster_name})"
  default     = "core"
}

###############################################
# Namespaces
###############################################

variable "namespaces" {
  type        = list(string)
  description = "Namespaces de Kubernetes a crear para las cargas"
  default     = ["frontend", "public-access", "administrative-access"]
}

###############################################
# Pipeline (compartido entre microservicios)
###############################################

variable "codestar_connection_arn" {
  type        = string
  description = "ARN del CodeStar/CodeConnections a GitHub para los pipelines"
  default     = null
}

variable "pipeline_artifact_bucket_name" {
  type        = string
  description = "Bucket S3 para artefactos de los pipelines"
  default     = null
}

###############################################
# Microservicios
###############################################

variable "microservices" {
  type = map(object({
    namespace          = string
    container_port     = optional(number, 8080)
    service_port       = optional(number, 80)
    replicas           = optional(number, 1)
    image              = optional(string, "")
    env                = optional(map(string), {})
    resources_requests = optional(map(string), { cpu = "256m", memory = "256Mi" })
    resources_limits   = optional(map(string), { cpu = "512m", memory = "512Mi" })
    policy_statements = optional(list(object({
      sid       = string
      effect    = string
      actions   = list(string)
      resources = list(string)
    })), [])

    # Ingress
    create_ingress      = optional(bool, false)
    ingress_class_name  = optional(string, "alb")
    ingress_annotations = optional(map(string), {})
    ingress_host        = optional(string, "")
    ingress_path        = optional(string, "/")

    # Pipeline
    create_pipeline     = optional(bool, false)
    pipeline_repository = optional(string, "")
    pipeline_branch     = optional(string, "main")
    pipeline_buildspec  = optional(string, "buildspec.yml")

    # ECR
    ecr_max_image_count  = optional(number, 10)
    image_tag_mutability = optional(string, "IMMUTABLE")
  }))
  description = "Mapa de microservicios a desplegar. La clave es el service_name (funcionalidad), ej. 'frontend'."
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
