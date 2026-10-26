output "bucket_id" {
  description = "ID of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_domain_name" {
  description = "Bucket domain name."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the bucket (created or provided)."
  value       = local.kms_key_arn
}

output "kms_key_id" {
  description = "ID of the KMS CMK created for the bucket (null if an external key was provided)."
  value       = var.create_kms_key ? aws_kms_key.this[0].key_id : null
}

output "kms_alias_name" {
  description = "Alias of the KMS CMK created for the bucket (null if an external key was provided)."
  value       = var.create_kms_key ? aws_kms_alias.this[0].name : null
}
