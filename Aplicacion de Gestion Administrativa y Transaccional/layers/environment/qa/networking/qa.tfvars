###############################################
# AGAT - Networking - QA
# VPC base: subnets public/private/data en 3 AZs,
# IGW + NAT zonal (salida a internet / IdP externo para pruebas).
###############################################

project     = "agat"
environment = "qa"
region      = "us-west-2"
profile     = ""

###############################################
# VPC
###############################################
vpc_name   = "core"
cidr_block = "10.20.0.0/16"

###############################################
# Feature flags IGW / NAT
###############################################
create_igw = true
create_nat = true
nat_mode   = "zonal"

###############################################
# Subnets (3 AZs: us-west-2a, us-west-2b, us-west-2c)
###############################################
subnet_config = {
  public = {
    custom_routes = []
    public        = true
    include_nat   = false
    subnets = [
      { cidr_block = "10.20.0.0/20", availability_zone = "a" },
      { cidr_block = "10.20.16.0/20", availability_zone = "b" },
      { cidr_block = "10.20.32.0/20", availability_zone = "c" },
    ]
  }

  private = {
    custom_routes = []
    public        = false
    include_nat   = true
    subnets = [
      { cidr_block = "10.20.48.0/20", availability_zone = "a" },
      { cidr_block = "10.20.64.0/20", availability_zone = "b" },
      { cidr_block = "10.20.80.0/20", availability_zone = "c" },
    ]
  }

  data = {
    custom_routes = []
    public        = false
    include_nat   = false
    subnets = [
      { cidr_block = "10.20.96.0/20", availability_zone = "a" },
      { cidr_block = "10.20.112.0/20", availability_zone = "b" },
      { cidr_block = "10.20.128.0/20", availability_zone = "c" },
    ]
  }
}

###############################################
# VPC Endpoints (ninguno requerido en este proyecto)
###############################################
vpc_endpoints = {}

###############################################
# Flow Logs
###############################################
create_flow_logs           = true
flow_log_retention_in_days = 30

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente    = "Calidad"
  Proyecto    = "AGAT"
  Descripcion = "Networking - VPC base - QA"
  Nombre      = "agat-qa-networking"
  ManagedBy   = "terraform"
  Repositorio = "AGAT_Infraestructura_IaC"
}
