locals {
  # Convención de nomenclatura AGAT: agat-{environment}-{componente}-{funcionalidad}
  # El componente (vpc) se incluye como literal, no se pasa como variable.
  base_name = "agat-${var.environment}"

  # Nombres de recursos principales
  vpc_name                  = "${local.base_name}-vpc-${var.name}"
  igw_name                  = "${local.base_name}-vpc-${var.name}-igw"
  nat_zonal_name            = "${local.base_name}-vpc-${var.name}-nat"
  nat_regional_name         = "${local.base_name}-vpc-${var.name}-nat-regional"
  eip_name                  = "${local.base_name}-vpc-${var.name}-eip"
  flow_logs_name            = "${local.base_name}-vpc-${var.name}-flow-logs"
  vpc_flow_log_name         = "${local.base_name}-vpc-${var.name}-flow-log"
  vpc_flow_logs_role_name   = "${local.base_name}-vpc-${var.name}-flow-logs-role-${var.aws_region}"
  vpc_flow_logs_policy_name = "${local.base_name}-vpc-${var.name}-flow-logs-policy-${var.aws_region}"
  default_sg_name           = "default"

  # Nombres de route tables por tipo de subnet
  route_table_names = {
    for key, config in var.subnet_config : key => "${local.base_name}-vpc-${var.name}-rtb-${key}"
  }

  # Nombres de subnets
  subnet_names = {
    for item in flatten([
      for network_key, network in var.subnet_config : [
        for subnet in network.subnets : {
          key               = "${network_key}-${index(network.subnets, subnet)}"
          service           = network_key
          subnet_index      = index(network.subnets, subnet)
          cidr_block        = subnet.cidr_block
          availability_zone = subnet.availability_zone
        }
      ]
      ]) : item.key => {
      name              = "${local.base_name}-vpc-${var.name}-subnet-${item.service}-${item.subnet_index + 1}"
      service           = item.service
      subnet_index      = item.subnet_index
      cidr_block        = item.cidr_block
      availability_zone = "${var.aws_region}${item.availability_zone}"
    }
  }

  # VPC Endpoints de tipo Gateway (S3, DynamoDB) - se asocian a route tables
  gateway_endpoints = {
    for key, cfg in var.vpc_endpoints : key => cfg if cfg.type == "Gateway"
  }

  # VPC Endpoints de tipo Interface (ej. DataSync) - se asocian a subnets + SG
  interface_endpoints = {
    for key, cfg in var.vpc_endpoints : key => cfg if cfg.type == "Interface"
  }
}
