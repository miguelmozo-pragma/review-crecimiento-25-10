###############################################
# Outputs
###############################################

# ---- Aurora ----
output "aurora_cluster_endpoint" {
  description = "Endpoint writer del cluster Aurora"
  value       = module.aurora.cluster_endpoint
}

output "aurora_reader_endpoint" {
  description = "Endpoint reader del cluster Aurora"
  value       = module.aurora.reader_endpoint
}

output "aurora_secret_arn" {
  description = "ARN del secret con las credenciales de Aurora"
  value       = module.aurora.secret_arn
}

output "aurora_security_group_id" {
  description = "Security group de Aurora"
  value       = module.aurora.security_group_id
}
