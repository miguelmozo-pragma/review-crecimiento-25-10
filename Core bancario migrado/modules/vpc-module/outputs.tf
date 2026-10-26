output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.vpc.arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.vpc.cidr_block
}

output "subnet_ids" {
  description = "Map of subnet IDs keyed by '{service}-{index}'"
  value = {
    for k, v in aws_subnet.subnet : k => v.id
  }
}

output "subnet_ids_by_service" {
  description = "Map of lists of subnet IDs grouped by subnet_config key (service). Useful for EKS/RDS which expect a list of subnets per tier."
  value = {
    for service_key in keys(var.subnet_config) : service_key => [
      for k, v in aws_subnet.subnet : v.id if local.subnet_names[k].service == service_key
    ]
  }
}

output "route_table_ids" {
  description = "Map of route table IDs"
  value = {
    for k, v in aws_route_table.route_table : k => v.id
  }
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (zonal or regional)"
  value       = var.create_nat ? (var.nat_mode == "regional" ? aws_nat_gateway.nat_regional[0].id : aws_nat_gateway.nat_zonal["nat-0"].id) : null
}

output "nat_gateway_mode" {
  description = "NAT Gateway mode (zonal or regional)"
  value       = var.nat_mode
}

output "regional_nat_gateway_route_table_id" {
  description = "Route table ID automatically created by regional NAT Gateway (only available in regional mode)"
  value       = var.create_nat && var.nat_mode == "regional" ? aws_nat_gateway.nat_regional[0].route_table_id : null
}

output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint IDs keyed by the logical endpoint name"
  value = merge(
    { for k, v in aws_vpc_endpoint.gateway : k => v.id },
    { for k, v in aws_vpc_endpoint.interface : k => v.id }
  )
}

output "interface_endpoint_dns_entries" {
  description = "Map of DNS entries for interface VPC endpoints keyed by the logical endpoint name"
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.dns_entry
  }
}
