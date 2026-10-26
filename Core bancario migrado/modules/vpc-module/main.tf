###########################################
########### VPC Resources #################
###########################################

resource "aws_vpc" "vpc" {
  provider = aws.project
  # checkov:skip=CKV2_AWS_11: In first version we won't use terraform flow logs
  cidr_block           = var.cidr_block
  instance_tenancy     = var.instance_tenancy
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  tags = merge(
    { Name = local.vpc_name },
    var.additional_tags
  )
}

###########################################
########## Subnet Resources ###############
###########################################

resource "aws_subnet" "subnet" {
  provider = aws.project
  for_each = local.subnet_names

  availability_zone = each.value.availability_zone
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr_block
  tags = merge(
    { Name = each.value.name },
    var.additional_tags
  )
}

resource "aws_route_table" "route_table" {
  provider = aws.project
  for_each = var.subnet_config
  vpc_id   = aws_vpc.vpc.id
  tags = merge(
    { Name = local.route_table_names[each.key] },
    var.additional_tags
  )
}

resource "aws_route_table_association" "subnet_association" {
  provider = aws.project
  for_each = local.subnet_names

  subnet_id      = aws_subnet.subnet[each.key].id
  route_table_id = aws_route_table.route_table[each.value.service].id
}

###########################################
########### IGW Resources #################
###########################################

resource "aws_internet_gateway" "igw" {
  provider = aws.project
  count    = var.create_igw ? 1 : 0
  vpc_id   = aws_vpc.vpc.id
  tags = merge(
    { Name = local.igw_name },
    var.additional_tags
  )
}

resource "aws_route" "internet_route" {
  provider               = aws.project
  for_each               = { for key, value in var.subnet_config : key => value if var.create_igw && value.public }
  route_table_id         = aws_route_table.route_table[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
}

###########################################
########### NAT Resources #################
###########################################

# Zonal NAT Gateway (original behavior)
resource "aws_nat_gateway" "nat_zonal" {
  provider = aws.project
  for_each = {
    for network_key, network in var.subnet_config : "nat-0" => {
      service : network_key
    } if network.public && length(network.subnets) > 0 && var.create_nat && var.nat_mode == "zonal" && try(network.subnets[0] != null, false)
  }

  allocation_id = aws_eip.eip[0].id
  subnet_id     = aws_subnet.subnet["${each.value.service}-0"].id

  tags = merge(
    { Name = local.nat_zonal_name },
    var.additional_tags
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# Regional NAT Gateway (new feature)
resource "aws_nat_gateway" "nat_regional" {
  provider = aws.project
  count    = var.create_nat && var.nat_mode == "regional" ? 1 : 0

  vpc_id            = aws_vpc.vpc.id
  availability_mode = "regional"

  # Manual mode: specify EIPs per AZ
  dynamic "availability_zone_address" {
    for_each = var.nat_regional_mode == "manual" ? var.nat_regional_az_config : []
    iterator = az_config
    content {
      availability_zone = az_config.value.availability_zone
      allocation_ids    = az_config.value.allocation_ids
    }
  }

  tags = merge(
    { Name = local.nat_regional_name },
    var.additional_tags
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# Routes to NAT Gateway (works for both zonal and regional)
resource "aws_route" "nat_route" {
  provider               = aws.project
  for_each               = { for key, value in var.subnet_config : key => value if var.create_nat && value.include_nat }
  route_table_id         = aws_route_table.route_table[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_mode == "regional" ? aws_nat_gateway.nat_regional[0].id : aws_nat_gateway.nat_zonal["nat-0"].id
}

# Custom routes for regional NAT Gateway route table (edge association)
resource "aws_route" "nat_regional_custom_route" {
  provider = aws.project
  for_each = {
    for idx, route in var.nat_regional_custom_routes : idx => route
    if var.create_nat && var.nat_mode == "regional"
  }

  route_table_id            = aws_nat_gateway.nat_regional[0].route_table_id
  destination_cidr_block    = each.value.destination_cidr_block
  carrier_gateway_id        = try(each.value.carrier_gateway_id, null)
  core_network_arn          = try(each.value.core_network_arn, null)
  egress_only_gateway_id    = try(each.value.egress_only_gateway_id, null)
  nat_gateway_id            = try(each.value.nat_gateway_id, null)
  local_gateway_id          = try(each.value.local_gateway_id, null)
  network_interface_id      = try(each.value.network_interface_id, null)
  transit_gateway_id        = try(each.value.transit_gateway_id, null)
  vpc_endpoint_id           = try(each.value.vpc_endpoint_id, null)
  vpc_peering_connection_id = try(each.value.vpc_peering_connection_id, null)
}

###########################################
############# EIP Resources ###############
###########################################

# EIP only needed for zonal NAT Gateway
# Regional NAT Gateway in auto mode manages IPs automatically
resource "aws_eip" "eip" {
  provider = aws.project
  count    = var.create_nat && var.nat_mode == "zonal" ? 1 : 0
  # checkov:skip=CKV2_AWS_19: this elastic ip is associated with nat, for that reason the alert can be ignored
  tags = merge(
    { Name = local.eip_name },
    var.additional_tags
  )
}

###########################################
######## Custom Route Resources ###########
###########################################

resource "aws_route" "custom_route" {
  provider = aws.project
  for_each = {
    for item in flatten([for netkwork_key, network in var.subnet_config : [for route in network.custom_routes : {
      "service" : netkwork_key
      "number_of_routes" : length(network.custom_routes)
      "route_index" : index(network.custom_routes, route)
      "destination_cidr_block" : route.destination_cidr_block
      "carrier_gateway_id" : route.carrier_gateway_id
      "core_network_arn"          = route.core_network_arn
      "egress_only_gateway_id"    = route.egress_only_gateway_id
      "nat_gateway_id"            = route.nat_gateway_id
      "local_gateway_id"          = route.local_gateway_id
      "network_interface_id"      = route.network_interface_id
      "transit_gateway_id"        = route.transit_gateway_id
      "vpc_endpoint_id"           = route.vpc_endpoint_id
      "vpc_peering_connection_id" = route.vpc_peering_connection_id

    }]]) : "${item.service}-route-${item.route_index}" => item if item.number_of_routes > 0
  }
  route_table_id            = aws_route_table.route_table["${each.value["service"]}"].id
  destination_cidr_block    = each.value["destination_cidr_block"]
  carrier_gateway_id        = try(each.value["carrier_gateway_id"], null)
  core_network_arn          = try(each.value["core_network_arn"], null)
  egress_only_gateway_id    = try(each.value["egress_only_gateway_id"], null)
  nat_gateway_id            = try(each.value["nat_gateway_id"], null)
  local_gateway_id          = try(each.value["local_gateway_id"], null)
  network_interface_id      = try(each.value["network_interface_id"], null)
  transit_gateway_id        = try(each.value["transit_gateway_id"], null)
  vpc_endpoint_id           = try(each.value["vpc_endpoint_id"], null)
  vpc_peering_connection_id = try(each.value["vpc_peering_connection_id"], null)
}

###########################################
######## VPC Endpoint Resources ###########
###########################################

# Gateway endpoints (S3, DynamoDB): associated to route tables of the given subnet_config keys
resource "aws_vpc_endpoint" "gateway" {
  provider          = aws.project
  for_each          = local.gateway_endpoints
  vpc_id            = aws_vpc.vpc.id
  service_name      = can(regex("^com\\.amazonaws\\.", each.value.service_name)) ? each.value.service_name : "com.amazonaws.${var.aws_region}.${each.value.service_name}"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    for rtk in each.value.route_table_keys : aws_route_table.route_table[rtk].id
  ]

  tags = merge(
    { Name = "${local.base_name}-vpc-${var.name}-vpce-${each.key}" },
    var.additional_tags
  )
}

# Interface endpoints (e.g. DataSync): ENIs placed in subnets, protected by security groups
resource "aws_vpc_endpoint" "interface" {
  provider            = aws.project
  for_each            = local.interface_endpoints
  vpc_id              = aws_vpc.vpc.id
  service_name        = can(regex("^com\\.amazonaws\\.", each.value.service_name)) ? each.value.service_name : "com.amazonaws.${var.aws_region}.${each.value.service_name}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = each.value.private_dns_enabled
  security_group_ids  = each.value.security_group_ids

  subnet_ids = [
    for sk in each.value.subnet_keys : aws_subnet.subnet["${sk}-0"].id
  ]

  tags = merge(
    { Name = "${local.base_name}-vpc-${var.name}-vpce-${each.key}" },
    var.additional_tags
  )
}

###########################################
####### Resource VPC Flow Logs  ###########
###########################################

resource "aws_iam_role" "vpc_flow_logs_role" {
  count    = var.create_flow_logs ? 1 : 0
  provider = aws.project
  name     = local.vpc_flow_logs_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    { Name = local.vpc_flow_logs_role_name },
    var.additional_tags
  )
}

resource "aws_iam_policy" "vpc_flow_logs_policy" {
  count    = var.create_flow_logs ? 1 : 0
  provider = aws.project
  name     = local.vpc_flow_logs_policy_name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs_role_policy_attachment" {
  count      = var.create_flow_logs ? 1 : 0
  provider   = aws.project
  role       = aws_iam_role.vpc_flow_logs_role[0].name
  policy_arn = aws_iam_policy.vpc_flow_logs_policy[0].arn
}

resource "aws_cloudwatch_log_group" "vpc_flow_log_group" {
  count             = var.create_flow_logs ? 1 : 0
  provider          = aws.project
  name              = "/aws/vpc/flow-logs/${aws_vpc.vpc.id}"
  retention_in_days = var.flow_log_retention_in_days
  tags = merge(
    { Name = local.flow_logs_name },
    var.additional_tags
  )
}

resource "aws_flow_log" "vpc_flow_log" {
  count                = var.create_flow_logs ? 1 : 0
  provider             = aws.project
  vpc_id               = aws_vpc.vpc.id
  log_destination      = aws_cloudwatch_log_group.vpc_flow_log_group[0].arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role[0].arn

  tags = merge(
    { Name = local.vpc_flow_log_name },
    var.additional_tags
  )
}

###########################################
####### Resource to solve CKV2_AWS_12 #####
###########################################
resource "aws_default_security_group" "default" {

  provider = aws.project
  vpc_id   = aws_vpc.vpc.id
  tags = merge(
    { Name = local.default_sg_name },
    var.additional_tags
  )
}
