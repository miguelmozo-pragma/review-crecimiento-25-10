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
# Variables VPC
###############################################

variable "vpc_name" {
  type        = string
  description = "Funcionalidad de la VPC (segmento funcionalidad del naming). Ej: 'core'"
  default     = "core"
}

variable "cidr_block" {
  type        = string
  description = "CIDR block de la VPC"
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Debe ser un CIDR válido."
  }
}

###############################################
# Variables Subnets
###############################################

variable "subnet_config" {
  type = map(object({
    custom_routes = list(object({
      destination_cidr_block    = string
      carrier_gateway_id        = optional(string)
      core_network_arn          = optional(string)
      egress_only_gateway_id    = optional(string)
      nat_gateway_id            = optional(string)
      local_gateway_id          = optional(string)
      network_interface_id      = optional(string)
      transit_gateway_id        = optional(string)
      vpc_endpoint_id           = optional(string)
      vpc_peering_connection_id = optional(string)
    }))
    public      = bool
    include_nat = optional(bool, false)
    subnets = list(object({
      cidr_block        = string
      availability_zone = string
    }))
  }))
  description = "Configuración de subnets por tier (public, private, data). Ver módulo vpc-module."
}

###############################################
# Feature flags IGW / NAT
###############################################

variable "create_igw" {
  type        = bool
  description = "Crear Internet Gateway"
  default     = true
}

variable "create_nat" {
  type        = bool
  description = "Crear NAT Gateway"
  default     = true
}

variable "nat_mode" {
  type        = string
  description = "Modo de NAT Gateway: 'zonal' o 'regional'"
  default     = "zonal"
  validation {
    condition     = contains(["zonal", "regional"], var.nat_mode)
    error_message = "nat_mode debe ser 'zonal' o 'regional'."
  }
}

###############################################
# Variables VPC Endpoints
###############################################

variable "vpc_endpoints" {
  type = map(object({
    service_name        = string
    type                = string
    route_table_keys    = optional(list(string), [])
    subnet_keys         = optional(list(string), [])
    security_group_ids  = optional(list(string), [])
    private_dns_enabled = optional(bool, true)
  }))
  description = "VPC endpoints a crear (Gateway/Interface). Ver módulo vpc-module."
  default     = {}
}

###############################################
# Variables Flow Logs
###############################################

variable "create_flow_logs" {
  type        = bool
  description = "Habilitar VPC Flow Logs"
  default     = false
}

variable "flow_log_retention_in_days" {
  type        = number
  description = "Días de retención de los flow logs"
  default     = 30
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
