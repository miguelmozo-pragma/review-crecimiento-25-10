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

# ---- Redis ----
output "redis_primary_endpoint" {
  description = "Endpoint primary de Redis"
  value       = module.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Endpoint reader de Redis"
  value       = module.redis.reader_endpoint_address
}

output "redis_security_group_id" {
  description = "Security group de Redis"
  value       = module.redis.security_group_id
}

# ---- S3 ----
output "s3_bucket_id" {
  description = "Nombre del bucket S3"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3"
  value       = module.s3.bucket_arn
}
