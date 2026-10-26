###############################################
# Core_Bancario - Networking - Prod
# VPC base: subnets public/private/data en 3 AZs,
# IGW + NAT zonal, VPC endpoint S3.
###############################################

project     = "cb"
environment = "prod"
region      = "us-west-2"
profile     = ""

###############################################
# VPC
###############################################
vpc_name   = "core"
cidr_block = "10.0.0.0/16"

###############################################
# Feature flags IGW / NAT
# Nota: en producción real estas cargas no tienen
# salida directa a internet; public/igw/nat se habilitan
# aquí para efectos de pruebas.
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
      { cidr_block = "10.0.0.0/20", availability_zone = "a" },
      { cidr_block = "10.0.16.0/20", availability_zone = "b" },
      { cidr_block = "10.0.32.0/20", availability_zone = "c" },
    ]
  }

  private = {
    custom_routes = []
    public        = false
    include_nat   = true
    subnets = [
      { cidr_block = "10.0.48.0/20", availability_zone = "a" },
      { cidr_block = "10.0.64.0/20", availability_zone = "b" },
      { cidr_block = "10.0.80.0/20", availability_zone = "c" },
    ]
  }

  data = {
    custom_routes = []
    public        = false
    include_nat   = false
    subnets = [
      { cidr_block = "10.0.96.0/20", availability_zone = "a" },
      { cidr_block = "10.0.112.0/20", availability_zone = "b" },
      { cidr_block = "10.0.128.0/20", availability_zone = "c" },
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
flow_log_retention_in_days = 30

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Produccion"
  Proyecto         = "Core_Bancario"
  Descripcion      = "Networking - VPC base - Prod"
  Nombre           = "cb-prod-networking"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
