output "replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.this.replication_instance_arn
}

output "replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = aws_dms_replication_instance.this.replication_instance_id
}

output "source_endpoint_arn" {
  description = "ARN of the source DMS endpoint"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "target_endpoint_arn" {
  description = "ARN of the target DMS endpoint"
  value       = aws_dms_endpoint.target.endpoint_arn
}

output "replication_task_arn" {
  description = "ARN of the DMS replication task"
  value       = aws_dms_replication_task.this.replication_task_arn
}

output "security_group_id" {
  description = "ID of the DMS replication instance security group"
  value       = aws_security_group.this.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used by DMS (created or passed)"
  value       = local.kms_key_arn
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret with source/target credentials"
  value       = aws_secretsmanager_secret.this.arn
}
