###############################################
# Gobierno: Processing
# Ambiente: ALL
#
# Recursos:
#   - Fraud Detector periféricos (CMK, bucket entrenamiento, rol, CloudWatch) (1)
#   - Managed Service for Apache Flink application + IAM + CloudWatch (1)
#   - SSM Parameters para comunicación entre layers (varios)
#
# NOTA: El detector de Fraud Detector (variables, labels, eventType,
# outcomes, rules, models) se gestiona FUERA de Terraform (el provider AWS
# no soporta recursos aws_frauddetector_*). Ver README.
###############################################

locals {
  # Property group por defecto para la app Flink si no se pasa ninguno.
  default_flink_property_groups = [
    {
      group_id = "RTDAConfig"
      property_map = {
        "kinesis.stream.name" = data.aws_ssm_parameter.kinesis_stream_name.value
        "aws.region"          = var.region
        "datalake.bucket"     = data.aws_ssm_parameter.datalake_bucket_name.value
        "fraud.detector.id"   = "rtda-${var.environment}-fraud-${var.fraud_name}"
      }
    }
  ]

  flink_property_groups = length(var.flink_property_groups) > 0 ? var.flink_property_groups : local.default_flink_property_groups
}

# ==========================================================================
# 1. Fraud Detector — recursos periféricos
# ==========================================================================
module "fraud_detector" {
  source = "../../modules/fraud-detector"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Específicas
  name                   = var.fraud_name
  create_training_bucket = var.fraud_create_training_bucket
  force_destroy          = var.fraud_force_destroy
  lifecycle_rules        = var.fraud_lifecycle_rules
  log_retention_in_days  = var.fraud_log_retention_in_days

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 2. Amazon Managed Service for Apache Flink
# ==========================================================================
module "flink" {
  source = "../../modules/flink"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Aplicación
  application_name    = var.flink_application_name
  runtime_environment = var.flink_runtime_environment
  start_application   = var.flink_start_application

  # Artefacto de código (en el bucket data lake, prefijo flink-code/)
  code_bucket_arn         = data.aws_ssm_parameter.datalake_bucket_arn.value
  code_bucket_name        = data.aws_ssm_parameter.datalake_bucket_name.value
  code_object_key         = var.flink_code_object_key
  code_bucket_kms_key_arn = data.aws_ssm_parameter.datalake_kms_key_arn.value

  # Runtime config
  parallelism          = var.flink_parallelism
  parallelism_per_kpu  = var.flink_parallelism_per_kpu
  auto_scaling_enabled = var.flink_auto_scaling_enabled
  log_level            = var.flink_log_level
  metrics_level        = var.flink_metrics_level
  property_groups      = local.flink_property_groups

  # Fuente Kinesis (del layer ingestion, vía SSM)
  kinesis_stream_arn         = data.aws_ssm_parameter.kinesis_stream_arn.value
  kinesis_stream_kms_key_arn = data.aws_ssm_parameter.kinesis_kms_key_arn.value

  # Fraud Detector: el detector se crea fuera de TF; se concede
  # GetEventPrediction sobre todos los detectores (acotar en prod).
  fraud_detector_arns = []

  # Salida procesada hacia el data lake
  output_bucket_arns         = [data.aws_ssm_parameter.datalake_bucket_arn.value]
  output_bucket_kms_key_arns = [data.aws_ssm_parameter.datalake_kms_key_arn.value]

  # Logging
  log_retention_in_days = var.flink_log_retention_in_days

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 3. SSM Parameters — comunicación entre layers
# ==========================================================================
resource "aws_ssm_parameter" "flink_application_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/processing/flink-application-arn"
  type     = "String"
  value    = module.flink.application_arn
  tags     = merge({ Name = "/rtda/${var.environment}/processing/flink-application-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "flink_application_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/processing/flink-application-name"
  type     = "String"
  value    = module.flink.application_name
  tags     = merge({ Name = "/rtda/${var.environment}/processing/flink-application-name" }, var.common_tags)
}

resource "aws_ssm_parameter" "fraud_service_role_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/processing/fraud-service-role-arn"
  type     = "String"
  value    = module.fraud_detector.service_role_arn
  tags     = merge({ Name = "/rtda/${var.environment}/processing/fraud-service-role-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "fraud_data_kms_key_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/processing/fraud-data-kms-key-arn"
  type     = "String"
  value    = module.fraud_detector.data_kms_key_arn
  tags     = merge({ Name = "/rtda/${var.environment}/processing/fraud-data-kms-key-arn" }, var.common_tags)
}
