output "delivery_stream_name" {
  description = "Name of the Firehose delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.this.name
}

output "delivery_stream_arn" {
  description = "ARN of the Firehose delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}

output "role_arn" {
  description = "ARN of the IAM role assumed by the delivery stream."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role assumed by the delivery stream."
  value       = aws_iam_role.this.name
}

output "log_group_name" {
  description = "CloudWatch log group name used by the delivery stream."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN used by the delivery stream."
  value       = aws_cloudwatch_log_group.this.arn
}

output "cloudwatch_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the CloudWatch log group (created or provided; empty if default encryption)."
  value       = local.cloudwatch_kms_key_arn
}

output "cloudwatch_kms_key_id" {
  description = "ID of the dedicated CloudWatch Logs CMK (null if not created)."
  value       = var.create_cloudwatch_kms_key ? aws_kms_key.cw[0].key_id : null
}
