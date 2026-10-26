###############################################
# Kinesis Data Stream
###############################################

output "kinesis_stream_arn" {
  description = "ARN del Kinesis Data Stream de ingesta."
  value       = module.kinesis.stream_arn
}

output "kinesis_stream_name" {
  description = "Nombre del Kinesis Data Stream de ingesta."
  value       = module.kinesis.stream_name
}

output "kinesis_kms_key_arn" {
  description = "ARN de la CMK que cifra el Kinesis Data Stream."
  value       = module.kinesis.kms_key_arn
}

###############################################
# Firehose delivery stream
###############################################

output "firehose_delivery_stream_arn" {
  description = "ARN del Firehose delivery stream."
  value       = module.firehose.delivery_stream_arn
}

output "firehose_delivery_stream_name" {
  description = "Nombre del Firehose delivery stream."
  value       = module.firehose.delivery_stream_name
}

output "firehose_role_arn" {
  description = "ARN del rol IAM asumido por el delivery stream."
  value       = module.firehose.role_arn
}

output "firehose_log_group_name" {
  description = "Nombre del log group de CloudWatch del delivery stream."
  value       = module.firehose.log_group_name
}
