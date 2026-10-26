###############################################
# Flink application
###############################################

output "flink_application_arn" {
  description = "ARN de la aplicación de Managed Service for Apache Flink."
  value       = module.flink.application_arn
}

output "flink_application_name" {
  description = "Nombre de la aplicación Flink."
  value       = module.flink.application_name
}

output "flink_execution_role_arn" {
  description = "ARN del rol de ejecución de la app Flink."
  value       = module.flink.execution_role_arn
}

output "flink_log_group_name" {
  description = "Log group de CloudWatch de la app Flink."
  value       = module.flink.log_group_name
}

###############################################
# Fraud Detector (periféricos)
###############################################

output "fraud_training_bucket_name" {
  description = "Bucket S3 de datos de entrenamiento de Fraud Detector."
  value       = module.fraud_detector.training_bucket_name
}

output "fraud_data_kms_key_arn" {
  description = "ARN de la CMK dedicada de datos de Fraud Detector."
  value       = module.fraud_detector.data_kms_key_arn
}

output "fraud_service_role_arn" {
  description = "ARN del rol de servicio de Fraud Detector."
  value       = module.fraud_detector.service_role_arn
}

output "fraud_log_group_name" {
  description = "Log group de CloudWatch de Fraud Detector."
  value       = module.fraud_detector.log_group_name
}
