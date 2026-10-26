###############################################
# SNS
###############################################

output "sns_topic_arn" {
  description = "ARN del tópico SNS de notificación de fraude."
  value       = module.sns.topic_arn
}

output "sns_topic_name" {
  description = "Nombre del tópico SNS."
  value       = module.sns.topic_name
}

output "sns_kms_key_arn" {
  description = "ARN de la CMK dedicada del tópico SNS."
  value       = module.sns.kms_key_arn
}

###############################################
# Lambda
###############################################

output "lambda_function_arn" {
  description = "ARN de la Lambda de evento de fraude."
  value       = module.lambda.function_arn
}

output "lambda_function_name" {
  description = "Nombre de la Lambda."
  value       = module.lambda.function_name
}

output "lambda_role_arn" {
  description = "ARN del rol de ejecución de la Lambda."
  value       = module.lambda.role_arn
}

output "lambda_log_group_name" {
  description = "Log group de CloudWatch de la Lambda."
  value       = module.lambda.log_group_name
}

output "lambda_alarm_arn" {
  description = "ARN de la alarma de errores de la Lambda."
  value       = module.lambda.alarm_arn
}
