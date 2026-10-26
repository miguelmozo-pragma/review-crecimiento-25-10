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
# CloudFront / ALB
###############################################

variable "distribution_name" {
  type        = string
  description = "Funcionalidad de la distribución (segmento funcionalidad). Nombre final: cb-{env}-cf-{distribution_name}"
  default     = "portal"
}

variable "alb_name" {
  type        = string
  description = "Nombre del ALB interno creado por el Ingress (load-balancer-name). Se resuelve vía data source."
  default     = "cb-prod-alb-public"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ARN del certificado ACM en us-east-1 para dominios custom. Null usa el certificado default de CloudFront."
  default     = null
}

variable "aliases" {
  type        = list(string)
  description = "Dominios custom (CNAMEs) de la distribución"
  default     = []
}

variable "price_class" {
  type        = string
  description = "Price class de CloudFront"
  default     = "PriceClass_100"
}

variable "web_acl_id" {
  type        = string
  description = "ARN del WAFv2 Web ACL (scope CLOUDFRONT, us-east-1) a asociar. Null para omitir."
  default     = null
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
