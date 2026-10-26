locals {
  base_name = "rtda-${var.environment}"

  # rtda-{env}-firehose-{funcionalidad}  e.g. rtda-dev-firehose-raw
  delivery_name = "${local.base_name}-firehose-${var.name}"

  # IAM role dedicated to the delivery stream
  role_name = "${local.base_name}-firehose-${var.name}-role"

  # CloudWatch log group: /rtda/{env}/firehose/{funcionalidad}
  log_group_name  = "/rtda/${var.environment}/firehose/${var.name}"
  log_stream_name = "S3Delivery"

  # Dedicated CloudWatch Logs CMK: rtda-{env}-kms-cw-{funcionalidad}
  cw_kms_alias_name = "alias/${local.base_name}-kms-cw-${var.name}"

  # Create-or-use branch for the CloudWatch Logs CMK. Empty string => default
  # CloudWatch-managed encryption (no customer key on the log group).
  cloudwatch_kms_key_arn = var.create_cloudwatch_kms_key ? aws_kms_key.cw[0].arn : var.cloudwatch_kms_key_arn
}
