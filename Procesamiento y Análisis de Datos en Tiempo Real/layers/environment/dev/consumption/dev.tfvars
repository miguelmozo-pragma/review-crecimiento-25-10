###############################################
# RTDA - Consumption - Dev
# SNS (notificación de fraude) + Lambda (evento de fraude)
###############################################

project     = "rtda"
environment = "dev"
region      = "us-west-2"
profile     = ""

# --- SNS ---
sns_topic_name    = "fraude"
sns_display_name  = "RTDA Fraude Dev"
sns_subscriptions = []

# --- Lambda ---
lambda_function_name        = "evento-fraude"
lambda_description          = "Genera un evento ante fraude y notifica vía SNS."
lambda_runtime              = "python3.12"
lambda_handler              = "app.lambda_handler"
lambda_memory_size          = 256
lambda_timeout              = 30
lambda_log_retention_days   = 30
lambda_reserved_concurrency = -1
lambda_read_from_stream     = true

# Tags corporativos
common_tags = {
  Ambiente    = "Desarrollo"
  Proyecto    = "RTDA"
  Descripcion = "Consumo SNS + Lambda evento de fraude - Dev"
  Nombre      = "rtda-dev-consumption"
  ManagedBy   = "terraform"
}
