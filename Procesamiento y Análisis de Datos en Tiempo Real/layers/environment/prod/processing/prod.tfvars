###############################################
# RTDA - Processing - Prod
# Flink (Managed Service for Apache Flink) + Fraud Detector (periféricos)
###############################################

project     = "rtda"
environment = "prod"
region      = "us-west-2"
profile     = ""

# --- Fraud Detector (periféricos) ---
fraud_name                   = "fraude"
fraud_create_training_bucket = true
fraud_force_destroy          = false
fraud_log_retention_in_days  = 90

# --- Flink application ---
flink_application_name      = "procesamiento"
flink_runtime_environment   = "FLINK-1_20"
flink_code_object_key       = "flink-code/app.zip"
flink_start_application     = false
flink_parallelism           = 4
flink_parallelism_per_kpu   = 1
flink_auto_scaling_enabled  = true
flink_log_level             = "WARN"
flink_metrics_level         = "APPLICATION"
flink_log_retention_in_days = 90

# Tags corporativos
common_tags = {
  Ambiente    = "Produccion"
  Proyecto    = "RTDA"
  Descripcion = "Procesamiento Flink + Fraud Detector - Prod"
  Nombre      = "rtda-prod-processing"
  ManagedBy   = "terraform"
}
