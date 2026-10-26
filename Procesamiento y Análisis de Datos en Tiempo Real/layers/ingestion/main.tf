###############################################
# Gobierno: Ingestion
# Ambiente: ALL
#
# Recursos:
#   - Kinesis Data Stream + KMS CMK (1)
#   - Kinesis Data Firehose -> S3 raw + IAM role + CloudWatch (1)
#   - SSM Parameters para comunicación entre layers (varios)
###############################################

# ==========================================================================
# 1. Kinesis Data Stream (ingesta en tiempo real)
# ==========================================================================
module "kinesis" {
  source = "../../modules/kinesis"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Variables específicas
  stream_name                 = var.stream_name
  stream_mode                 = var.stream_mode
  shard_count                 = var.shard_count
  retention_period            = var.retention_period
  shard_level_metrics         = var.shard_level_metrics
  kms_deletion_window_in_days = var.kinesis_kms_deletion_window_in_days

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 2. Kinesis Data Firehose (entrega del stream hacia el bucket S3 raw)
# ==========================================================================
module "firehose" {
  source = "../../modules/firehose"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Fuente: Kinesis Data Stream
  kinesis_stream_arn         = module.kinesis.stream_arn
  kinesis_stream_kms_key_arn = module.kinesis.kms_key_arn

  # Destino: bucket S3 raw (del layer storage, vía SSM)
  name                    = var.firehose_name
  destination_bucket_arn  = data.aws_ssm_parameter.raw_bucket_arn.value
  destination_kms_key_arn = data.aws_ssm_parameter.raw_kms_key_arn.value
  s3_prefix               = var.s3_prefix
  s3_error_output_prefix  = var.s3_error_output_prefix
  buffering_size          = var.buffering_size
  buffering_interval      = var.buffering_interval
  compression_format      = var.compression_format

  # Logging cifrado con CMK dedicada de CloudWatch (la crea el módulo)
  log_retention_in_days = var.firehose_log_retention_in_days

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 3. SSM Parameters — comunicación entre layers
# ==========================================================================

# --- Kinesis stream (consumido por el layer processing / Flink) ---
resource "aws_ssm_parameter" "kinesis_stream_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-stream-arn"
  type     = "String"
  value    = module.kinesis.stream_arn
  tags     = merge({ Name = "/rtda/${var.environment}/ingestion/kinesis-stream-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "kinesis_stream_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-stream-name"
  type     = "String"
  value    = module.kinesis.stream_name
  tags     = merge({ Name = "/rtda/${var.environment}/ingestion/kinesis-stream-name" }, var.common_tags)
}

resource "aws_ssm_parameter" "kinesis_kms_key_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-kms-key-arn"
  type     = "String"
  value    = module.kinesis.kms_key_arn
  tags     = merge({ Name = "/rtda/${var.environment}/ingestion/kinesis-kms-key-arn" }, var.common_tags)
}

# --- Firehose delivery stream ---
resource "aws_ssm_parameter" "firehose_delivery_stream_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/firehose-delivery-stream-arn"
  type     = "String"
  value    = module.firehose.delivery_stream_arn
  tags     = merge({ Name = "/rtda/${var.environment}/ingestion/firehose-delivery-stream-arn" }, var.common_tags)
}
