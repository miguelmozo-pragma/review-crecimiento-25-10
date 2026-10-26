###############################################
# RTDA - Ingestion - QA
# Kinesis Data Stream + Firehose -> S3 raw
###############################################

project     = "rtda"
environment = "qa"
region      = "us-west-2"
profile     = ""

# --- Kinesis Data Stream ---
stream_name      = "ingesta"
stream_mode      = "ON_DEMAND"
shard_count      = null
retention_period = 48

# --- Firehose delivery stream ---
firehose_name                  = "raw"
s3_prefix                      = "raw/"
s3_error_output_prefix         = "errors/"
buffering_size                 = 5
buffering_interval             = 120
compression_format             = "GZIP"
firehose_log_retention_in_days = 30

# Tags corporativos
common_tags = {
  Ambiente    = "Calidad"
  Proyecto    = "RTDA"
  Descripcion = "Ingesta Kinesis + Firehose - QA"
  Nombre      = "rtda-qa-ingestion"
  ManagedBy   = "terraform"
}
