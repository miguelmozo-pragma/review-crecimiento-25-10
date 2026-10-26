###############################################
# RTDA - Consumption - QA
# SNS (notificación de fraude) + Lambda (evento de fraude)
###############################################

project     = "rtda"
environment = "qa"
region      = "us-west-2"
profile     = ""

# --- SNS ---
sns_topic_name    = "fraude"
sns_display_name  = "RTDA Fraude QA"
sns_subscriptions = []

# --- Lambda ---
lambda_function_name        = "evento-fraude"
lambda_description          = "Genera un evento ante fraude y notifica vía SNS."
lambda_runtime              = "python3.12"
lambda_handler              = "app.lambda_handler"
lambda_memory_size          = 512
lambda_timeout              = 60
lambda_log_retention_days   = 30
lambda_reserved_concurrency = -1
lambda_read_from_stream     = true

# Tags corporativos
common_tags = {
  Ambiente    = "Calidad"
  Proyecto    = "RTDA"
  Descripcion = "Consumo SNS + Lambda evento de fraude - QA"
  Nombre      = "rtda-qa-consumption"
  ManagedBy   = "terraform"
}
