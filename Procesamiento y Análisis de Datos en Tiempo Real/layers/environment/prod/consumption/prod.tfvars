###############################################
# RTDA - Consumption - Prod
# SNS (notificación de fraude) + Lambda (evento de fraude)
###############################################

project     = "rtda"
environment = "prod"
region      = "us-west-2"
profile     = ""

# --- SNS ---
sns_topic_name    = "fraude"
sns_display_name  = "RTDA Fraude Prod"
sns_subscriptions = []

# --- Lambda ---
lambda_function_name        = "evento-fraude"
lambda_description          = "Genera un evento ante fraude y notifica vía SNS."
lambda_runtime              = "python3.12"
lambda_handler              = "app.lambda_handler"
lambda_memory_size          = 1024
lambda_timeout              = 60
lambda_log_retention_days   = 90
lambda_reserved_concurrency = -1
lambda_read_from_stream     = true

# Tags corporativos
common_tags = {
  Ambiente    = "Produccion"
  Proyecto    = "RTDA"
  Descripcion = "Consumo SNS + Lambda evento de fraude - Prod"
  Nombre      = "rtda-prod-consumption"
  ManagedBy   = "terraform"
}
