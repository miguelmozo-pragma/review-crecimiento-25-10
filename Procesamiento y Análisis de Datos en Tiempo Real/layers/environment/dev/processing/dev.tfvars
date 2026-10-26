###############################################
# RTDA - Processing - Dev
# Flink (Managed Service for Apache Flink) + Fraud Detector (periféricos)
###############################################

project     = "rtda"
environment = "dev"
region      = "us-west-2"
profile     = ""

# --- Fraud Detector (periféricos) ---
fraud_name                   = "fraude"
fraud_create_training_bucket = true
fraud_force_destroy          = true
fraud_log_retention_in_days  = 30

# --- Flink application ---
flink_application_name      = "procesamiento"
flink_runtime_environment   = "FLINK-1_20"
flink_code_object_key       = "flink-code/app.zip"
flink_start_application     = false
flink_parallelism           = 1
flink_parallelism_per_kpu   = 1
flink_auto_scaling_enabled  = true
flink_log_level             = "INFO"
flink_metrics_level         = "APPLICATION"
flink_log_retention_in_days = 30

# Tags corporativos
common_tags = {
  Ambiente    = "Desarrollo"
  Proyecto    = "RTDA"
  Descripcion = "Procesamiento Flink + Fraud Detector - Dev"
  Nombre      = "rtda-dev-processing"
  ManagedBy   = "terraform"
}
