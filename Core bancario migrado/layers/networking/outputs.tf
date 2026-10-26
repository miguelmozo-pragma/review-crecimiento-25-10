###############################################
# Outputs
###############################################

output "vpc_id" {
  description = "ID de la VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "ARN de la VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "CIDR block de la VPC"
  value       = module.vpc.vpc_cidr_block
}

output "subnet_ids" {
  description = "Mapa de IDs de subnets por clave '{tier}-{indice}'"
  value       = module.vpc.subnet_ids
}

output "subnet_ids_by_service" {
  description = "Mapa de listas de IDs de subnets agrupadas por tier (public, private, data)"
  value       = module.vpc.subnet_ids_by_service
}

output "route_table_ids" {
  description = "Mapa de IDs de route tables por tier"
  value       = module.vpc.route_table_ids
}

output "nat_gateway_id" {
  description = "ID del NAT Gateway"
  value       = module.vpc.nat_gateway_id
}

output "vpc_endpoint_ids" {
  description = "Mapa de IDs de los VPC endpoints"
  value       = module.vpc.vpc_endpoint_ids
}
