###############################################
# Bucket RAW
###############################################

output "raw_bucket_name" {
  description = "Nombre del bucket S3 raw (destino de Firehose)."
  value       = module.s3_raw.bucket_name
}

output "raw_bucket_arn" {
  description = "ARN del bucket S3 raw."
  value       = module.s3_raw.bucket_arn
}

output "raw_kms_key_arn" {
  description = "ARN de la CMK que cifra el bucket raw."
  value       = module.s3_raw.kms_key_arn
}

###############################################
# Bucket DATA LAKE
###############################################

output "datalake_bucket_name" {
  description = "Nombre del bucket S3 data lake."
  value       = module.s3_datalake.bucket_name
}

output "datalake_bucket_arn" {
  description = "ARN del bucket S3 data lake."
  value       = module.s3_datalake.bucket_arn
}

output "datalake_kms_key_arn" {
  description = "ARN de la CMK que cifra el bucket data lake."
  value       = module.s3_datalake.kms_key_arn
}

###############################################
# Lake Formation
###############################################

output "datalake_database_name" {
  description = "Nombre de la base de datos del Glue Data Catalog gobernada por Lake Formation."
  value       = module.lakeformation.database_name
}

output "datalake_database_arn" {
  description = "ARN de la base de datos del Glue Data Catalog."
  value       = module.lakeformation.database_arn
}

output "lakeformation_registered_location_arn" {
  description = "ARN de la ubicación S3 registrada en Lake Formation."
  value       = module.lakeformation.registered_location_arn
}
