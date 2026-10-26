output "stream_name" {
  description = "Name of the Kinesis Data Stream."
  value       = aws_kinesis_stream.this.name
}

output "stream_arn" {
  description = "ARN of the Kinesis Data Stream."
  value       = aws_kinesis_stream.this.arn
}

output "stream_mode" {
  description = "Capacity mode of the stream (ON_DEMAND or PROVISIONED)."
  value       = var.stream_mode
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the stream (created or provided)."
  value       = local.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS CMK created for the stream (null if an external key was provided)."
  value       = var.create_kms_key ? aws_kms_key.this[0].key_id : null
}

output "kms_alias_name" {
  description = "Alias of the KMS CMK created for the stream (null if an external key was provided)."
  value       = var.create_kms_key ? aws_kms_alias.this[0].name : null
}
