###########################################
# Outputs
###########################################

output "replication_group_id" {
  description = "Id of the ElastiCache Redis replication group."
  value       = aws_elasticache_replication_group.this.id
}

output "replication_group_arn" {
  description = "ARN of the ElastiCache Redis replication group."
  value       = aws_elasticache_replication_group.this.arn
}

output "primary_endpoint_address" {
  description = "Primary (write) endpoint address of the replication group."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Reader endpoint address of the replication group."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Redis port."
  value       = 6379
}

output "security_group_id" {
  description = "Id of the security group controlling access to Redis."
  value       = aws_security_group.this.id
}

output "kms_key_arn" {
  description = "Effective KMS CMK ARN used for encryption at rest (created or passed)."
  value       = local.kms_key_arn
}
