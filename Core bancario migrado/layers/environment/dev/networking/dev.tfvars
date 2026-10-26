###############################################
# Core_Bancario - Networking - Dev
# VPC base: subnets public/private/data en 1 AZ,
# IGW + NAT zonal (salida a internet para pruebas).
###############################################

project     = "cb"
environment = "dev"
region      = "us-west-2"
profile     = ""

###############################################
# VPC
###############################################
vpc_name   = "core"
cidr_block = "10.10.0.0/16"

###############################################
# Feature flags IGW / NAT
###############################################
create_igw = true
create_nat = true
nat_mode   = "zonal"

###############################################
# Subnets (2 AZs: us-west-2a, us-west-2b)
# Nota: el cómputo de dev usa 1 AZ, pero Aurora/EKS/ElastiCache
# exigen subnet groups en >= 2 AZs, por lo que la red abarca 2 AZs.
###############################################
subnet_config = {
  public = {
    custom_routes = []
    public        = true
    include_nat   = false
    subnets = [
      { cidr_block = "10.10.0.0/20", availability_zone = "a" },
      { cidr_block = "10.10.16.0/20", availability_zone = "b" },
    ]
  }

  private = {
    custom_routes = []
    public        = false
    include_nat   = true
    subnets = [
      { cidr_block = "10.10.48.0/20", availability_zone = "a" },
      { cidr_block = "10.10.64.0/20", availability_zone = "b" },
    ]
  }

  data = {
    custom_routes = []
    public        = false
    include_nat   = false
    subnets = [
      { cidr_block = "10.10.96.0/20", availability_zone = "a" },
      { cidr_block = "10.10.112.0/20", availability_zone = "b" },
    ]
  }
}

###############################################
# VPC Endpoints
###############################################
vpc_endpoints = {
  s3 = {
    service_name     = "s3"
    type             = "Gateway"
    route_table_keys = ["private", "data"]
  }
}

###############################################
# Flow Logs
###############################################
create_flow_logs           = true
flow_log_retention_in_days = 14

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente    = "Desarrollo"
  Proyecto    = "Core_Bancario"
  Descripcion = "Networking - VPC base - Dev"
  Nombre      = "cb-dev-networking"
  ManagedBy   = "terraform"
  Repositorio = "Core_Bancario_Infraestructura_IaC"
}
