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
# Variables EKS
###############################################

variable "cluster_name" {
  type        = string
  description = "Funcionalidad del cluster EKS (segmento funcionalidad). Nombre final: cb-{env}-eks-{cluster_name}"
  default     = "core"
}

variable "cluster_version" {
  type        = string
  description = "Versión de Kubernetes del cluster EKS"
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Habilitar acceso público al endpoint del API server de EKS"
  default     = false
}

variable "cluster_endpoint_private_access" {
  type        = bool
  description = "Habilitar acceso privado al endpoint del API server de EKS"
  default     = true
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = optional(number, 20)
    labels         = optional(map(string), {})
    taints = optional(map(object({
      key    = string
      value  = optional(string)
      effect = string
    })), {})
  }))
  description = "Node groups administrados de EKS (dimensionamiento por ambiente)"
}

###############################################
# Addons
###############################################

variable "enable_lb_controller" {
  type        = bool
  description = "Desplegar AWS Load Balancer Controller"
  default     = true
}

variable "ebs_csi_driver" {
  type        = bool
  description = "Instalar el addon EBS CSI driver con rol IRSA dedicado"
  default     = true
}

variable "enable_karpenter" {
  type        = bool
  description = "Desplegar Karpenter (autoscaler)"
  default     = true
}

variable "karpenter_chart_version" {
  type        = string
  description = "Versión del chart de Karpenter"
  default     = "1.8.2"
}

variable "karpenter_capacity_types" {
  type        = list(string)
  description = "Tipos de capacidad que Karpenter puede aprovisionar (spot, on-demand)"
  default     = ["spot"]
}

variable "karpenter_node_cpu_limit" {
  type        = string
  description = "Límite total de CPU del NodePool de Karpenter"
  default     = "1000"
}

variable "karpenter_node_memory_limit" {
  type        = string
  description = "Límite total de memoria del NodePool de Karpenter (ej. 1000Gi)"
  default     = "1000Gi"
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
