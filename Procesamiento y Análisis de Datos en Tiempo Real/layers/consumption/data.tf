data "aws_caller_identity" "current" {
  provider = aws.project
}

data "aws_region" "current" {
  provider = aws.project
}

###############################################
# Outputs del layer ingestion (vía SSM)
###############################################

# Kinesis stream: la Lambda puede leer resultados del procesamiento
data "aws_ssm_parameter" "kinesis_stream_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-stream-arn"
}

data "aws_ssm_parameter" "kinesis_kms_key_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-kms-key-arn"
}
