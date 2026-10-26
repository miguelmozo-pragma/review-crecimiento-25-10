###############################################
# Gobierno: Consumption
# Ambiente: ALL
#
# Recursos:
#   - SNS topic (notificación de fraude) + KMS CMK (1)
#   - Lambda (evento de fraude) + IAM + CloudWatch + alarma (1)
#   - SSM Parameters para comunicación entre layers (varios)
#
# Flujo: la Lambda genera el evento de fraude y publica en el tópico SNS.
# La alarma de errores de la Lambda también notifica al tópico SNS.
###############################################

# Paquete placeholder de la Lambda (cuando no se provee un artefacto en S3).
# El código real se despliega por fuera (pipeline) sobrescribiendo el paquete.
data "archive_file" "lambda_placeholder" {
  count       = var.lambda_s3_bucket == null ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/placeholder"
  output_path = "${path.module}/.build/lambda-placeholder.zip"
}

# ==========================================================================
# 1. SNS topic (notificación de fraude)
# ==========================================================================
module "sns" {
  source = "../../modules/sns"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Específicas
  topic_name    = var.sns_topic_name
  display_name  = var.sns_display_name
  subscriptions = var.sns_subscriptions

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 2. Lambda (genera el evento de fraude y notifica vía SNS)
# ==========================================================================
module "lambda" {
  source = "../../modules/lambda"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Función
  function_name = var.lambda_function_name
  description   = var.lambda_description
  runtime       = var.lambda_runtime
  handler       = var.lambda_handler
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout

  # Paquete: artefacto en S3 si se provee, si no, placeholder local
  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key
  filename  = var.lambda_s3_bucket == null ? data.archive_file.lambda_placeholder[0].output_path : null

  # Concurrencia y logging
  reserved_concurrent_executions = var.lambda_reserved_concurrency
  log_retention_days             = var.lambda_log_retention_days

  # Variables de entorno (combinadas con las inyectadas por el layer)
  environment_variables = merge(
    {
      SNS_TOPIC_ARN = module.sns.topic_arn
      ENVIRONMENT   = var.environment
    },
    var.lambda_environment_variables
  )

  # Permisos de mínimo privilegio
  policy_statements = concat(
    [
      {
        sid       = "PublishToSns"
        effect    = "Allow"
        actions   = ["sns:Publish"]
        resources = [module.sns.topic_arn]
      },
      {
        sid       = "UseSnsKms"
        effect    = "Allow"
        actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
        resources = [coalesce(module.sns.kms_key_arn, module.sns.kms_key_id)]
      }
    ],
    var.lambda_read_from_stream ? [
      {
        sid    = "ReadKinesisStream"
        effect = "Allow"
        actions = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        resources = [data.aws_ssm_parameter.kinesis_stream_arn.value]
      },
      {
        sid       = "UseKinesisKms"
        effect    = "Allow"
        actions   = ["kms:Decrypt"]
        resources = [data.aws_ssm_parameter.kinesis_kms_key_arn.value]
      }
    ] : []
  )

  # La alarma de errores notifica al tópico SNS
  create_alarm  = true
  alarm_actions = [module.sns.topic_arn]

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 3. SSM Parameters — comunicación entre layers
# ==========================================================================
resource "aws_ssm_parameter" "sns_topic_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/consumption/sns-topic-arn"
  type     = "String"
  value    = module.sns.topic_arn
  tags     = merge({ Name = "/rtda/${var.environment}/consumption/sns-topic-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "lambda_function_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/consumption/lambda-function-arn"
  type     = "String"
  value    = module.lambda.function_arn
  tags     = merge({ Name = "/rtda/${var.environment}/consumption/lambda-function-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "lambda_function_name" {
  provider = aws.project
  name     = "/rtda/${var.environment}/consumption/lambda-function-name"
  type     = "String"
  value    = module.lambda.function_name
  tags     = merge({ Name = "/rtda/${var.environment}/consumption/lambda-function-name" }, var.common_tags)
}
