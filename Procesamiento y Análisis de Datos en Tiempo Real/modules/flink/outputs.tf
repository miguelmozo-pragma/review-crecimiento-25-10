output "application_name" {
  description = "Name of the Managed Service for Apache Flink application."
  value       = aws_kinesisanalyticsv2_application.this.name
}

output "application_arn" {
  description = "ARN of the Flink application."
  value       = aws_kinesisanalyticsv2_application.this.arn
}

output "application_version_id" {
  description = "Current version id of the Flink application."
  value       = aws_kinesisanalyticsv2_application.this.version_id
}

output "execution_role_arn" {
  description = "ARN of the IAM execution role used by the application (created or provided)."
  value       = local.execution_role_arn
}

output "execution_role_name" {
  description = "Name of the IAM execution role created for the application (null if an external role was provided)."
  value       = var.create_execution_role ? aws_iam_role.this[0].name : null
}

output "log_group_name" {
  description = "CloudWatch log group name used by the application."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN used by the application."
  value       = aws_cloudwatch_log_group.this.arn
}

output "cloudwatch_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the CloudWatch log group (empty if default encryption)."
  value       = local.cloudwatch_kms_key_arn
}
