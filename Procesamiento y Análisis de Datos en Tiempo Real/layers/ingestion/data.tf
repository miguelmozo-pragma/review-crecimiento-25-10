data "aws_caller_identity" "current" {
  provider = aws.project
}

data "aws_region" "current" {
  provider = aws.project
}

###############################################
# Outputs del layer storage (vía SSM Parameter Store)
###############################################

# Nombre del bucket raw (destino de Firehose)
data "aws_ssm_parameter" "raw_bucket_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/raw-bucket-name"
}

# ARN del bucket raw
data "aws_ssm_parameter" "raw_bucket_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/raw-bucket-arn"
}

# ARN de la CMK que cifra el bucket raw
data "aws_ssm_parameter" "raw_kms_key_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/storage/raw-kms-key-arn"
}
