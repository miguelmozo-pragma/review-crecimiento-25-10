data "aws_caller_identity" "current" {
  provider = aws.project
}

data "aws_region" "current" {
  provider = aws.project
}

###############################################
# Outputs del layer ingestion (vía SSM)
###############################################

# Kinesis stream fuente para la app Flink
data "aws_ssm_parameter" "kinesis_stream_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-stream-arn"
}

data "aws_ssm_parameter" "kinesis_stream_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-stream-name"
}

data "aws_ssm_parameter" "kinesis_kms_key_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-kms-key-arn"
}

###############################################
# Outputs del layer storage (vía SSM)
###############################################

# Bucket data lake: artefacto de código Flink + salida procesada
data "aws_ssm_parameter" "datalake_bucket_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/datalake-bucket-name"
}

data "aws_ssm_parameter" "datalake_bucket_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/datalake-bucket-arn"
}

data "aws_ssm_parameter" "datalake_kms_key_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/datalake-kms-key-arn"
}
