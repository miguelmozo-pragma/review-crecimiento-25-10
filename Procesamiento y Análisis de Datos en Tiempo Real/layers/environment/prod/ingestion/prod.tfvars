###############################################
# RTDA - Ingestion - Prod
# Kinesis Data Stream + Firehose -> S3 raw
###############################################

project     = "rtda"
environment = "prod"
region      = "us-west-2"
profile     = ""

# --- Kinesis Data Stream ---
stream_name      = "ingesta"
stream_mode      = "PROVISIONED"
shard_count      = 2
retention_period = 168

# --- Firehose delivery stream ---
firehose_name                  = "raw"
s3_prefix                      = "raw/"
s3_error_output_prefix         = "errors/"
buffering_size                 = 64
buffering_interval             = 60
compression_format             = "GZIP"
firehose_log_retention_in_days = 90

# Tags corporativos
common_tags = {
  Ambiente    = "Produccion"
  Proyecto    = "RTDA"
  Descripcion = "Ingesta Kinesis + Firehose - Prod"
  Nombre      = "rtda-prod-ingestion"
  ManagedBy   = "terraform"
}
