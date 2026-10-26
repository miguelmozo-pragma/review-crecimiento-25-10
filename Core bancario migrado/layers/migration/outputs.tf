###############################################
# Outputs
###############################################

# ---- DMS ----
output "dms_replication_instance_arn" {
  description = "ARN de la replication instance de DMS"
  value       = module.dms.replication_instance_arn
}

output "dms_source_endpoint_arn" {
  description = "ARN del endpoint source (PostgreSQL on-prem)"
  value       = module.dms.source_endpoint_arn
}

output "dms_target_endpoint_arn" {
  description = "ARN del endpoint target (Aurora)"
  value       = module.dms.target_endpoint_arn
}

output "dms_replication_task_arn" {
  description = "ARN de la replication task de DMS"
  value       = module.dms.replication_task_arn
}

output "dms_secret_arn" {
  description = "ARN del secret con credenciales source/target de DMS"
  value       = module.dms.secret_arn
}

# ---- DataSync ----
output "datasync_vpc_endpoint_id" {
  description = "ID del VPC endpoint (interface) de DataSync"
  value       = aws_vpc_endpoint.datasync.id
}

output "datasync_security_group_id" {
  description = "Security group del VPC endpoint de DataSync"
  value       = aws_security_group.datasync.id
}

output "datasync_endpoint_dns" {
  description = "DNS entries del VPC endpoint de DataSync"
  value       = aws_vpc_endpoint.datasync.dns_entry
}
