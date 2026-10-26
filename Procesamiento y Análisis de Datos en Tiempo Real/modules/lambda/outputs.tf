output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function."
  value       = aws_lambda_function.this.invoke_arn
}

output "qualified_arn" {
  description = "Qualified ARN of the Lambda function (includes version)."
  value       = aws_lambda_function.this.qualified_arn
}

output "role_arn" {
  description = "ARN of the IAM role attached to the function."
  value       = var.create_role ? aws_iam_role.this[0].arn : var.existing_role_arn
}

output "role_name" {
  description = "Name of the IAM role attached to the function (null if external role)."
  value       = var.create_role ? aws_iam_role.this[0].name : null
}

output "log_group_name" {
  description = "Name of the CloudWatch log group."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group."
  value       = aws_cloudwatch_log_group.this.arn
}

output "cloudwatch_kms_key_arn" {
  description = "ARN of the KMS key encrypting the log group (empty if default encryption)."
  value       = local.cloudwatch_kms_key_arn
}

output "alarm_arn" {
  description = "ARN of the CloudWatch error alarm (null if not created)."
  value       = var.create_alarm ? aws_cloudwatch_metric_alarm.errors[0].arn : null
}
