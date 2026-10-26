###########################################
# Outputs
###########################################

output "cluster_identifier" {
  description = "Identifier of the Aurora cluster."
  value       = aws_rds_cluster.this.cluster_identifier
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster."
  value       = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Writer endpoint of the Aurora cluster."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint of the Aurora cluster."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  description = "Port the Aurora cluster listens on."
  value       = local.port
}

output "database_name" {
  description = "Name of the initial database."
  value       = var.database_name
}

output "security_group_id" {
  description = "ID of the Aurora security group."
  value       = aws_security_group.aurora.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the cluster and secret."
  value       = local.kms_key_arn
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master credentials."
  value       = aws_secretsmanager_secret.aurora.arn
}

output "master_username" {
  description = "Master username for the Aurora cluster."
  value       = var.master_username
}
