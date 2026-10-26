output "topic_arn" {
  description = "ARN of the SNS topic."
  value       = aws_sns_topic.this.arn
}

output "topic_name" {
  description = "Name of the SNS topic."
  value       = aws_sns_topic.this.name
}

output "kms_key_id" {
  description = "Id/ARN of the KMS key used to encrypt the topic (created or provided)."
  value       = local.kms_key_id
}

output "kms_key_arn" {
  description = "ARN of the dedicated KMS CMK (null if an external key was provided)."
  value       = var.create_kms_key ? aws_kms_key.this[0].arn : null
}

output "kms_alias_name" {
  description = "Alias of the dedicated KMS CMK (null if an external key was provided)."
  value       = var.create_kms_key ? aws_kms_alias.this[0].name : null
}

output "subscription_arns" {
  description = "Map of subscription keys to their ARNs."
  value       = { for k, s in aws_sns_topic_subscription.this : k => s.arn }
}
