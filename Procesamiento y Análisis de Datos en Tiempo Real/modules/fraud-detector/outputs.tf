output "training_bucket_name" {
  description = "Name of the Fraud Detector training-data S3 bucket (null if not created)."
  value       = var.create_training_bucket ? aws_s3_bucket.training[0].bucket : null
}

output "training_bucket_arn" {
  description = "ARN of the Fraud Detector training-data S3 bucket (null if not created)."
  value       = var.create_training_bucket ? aws_s3_bucket.training[0].arn : null
}

output "data_kms_key_arn" {
  description = "ARN of the dedicated data CMK (created or provided)."
  value       = local.kms_key_arn
}

output "data_kms_key_id" {
  description = "ID of the dedicated data CMK (null if an external key was provided)."
  value       = var.create_kms_key ? aws_kms_key.this[0].key_id : null
}

output "service_role_arn" {
  description = "ARN of the Fraud Detector service role (null if not created)."
  value       = var.create_service_role ? aws_iam_role.this[0].arn : null
}

output "service_role_name" {
  description = "Name of the Fraud Detector service role (null if not created)."
  value       = var.create_service_role ? aws_iam_role.this[0].name : null
}

output "log_group_name" {
  description = "CloudWatch log group name (null if not created)."
  value       = var.create_log_group ? aws_cloudwatch_log_group.this[0].name : null
}

output "log_group_arn" {
  description = "CloudWatch log group ARN (null if not created)."
  value       = var.create_log_group ? aws_cloudwatch_log_group.this[0].arn : null
}
