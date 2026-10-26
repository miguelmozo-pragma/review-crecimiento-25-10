locals {
  base_name = "rtda-${var.environment}"

  # rtda-{env}-flink-{funcionalidad}  e.g. rtda-dev-flink-procesamiento
  application_name = "${local.base_name}-flink-${var.application_name}"

  # IAM execution role dedicated to the Flink application
  role_name = "${local.base_name}-flink-${var.application_name}-role"

  # CloudWatch log group: /rtda/{env}/flink/{funcionalidad}
  log_group_name  = "/rtda/${var.environment}/flink/${var.application_name}"
  log_stream_name = "kinesis-analytics"

  # Dedicated CloudWatch Logs CMK: rtda-{env}-kms-cw-flink-{funcionalidad}
  cw_kms_alias_name = "alias/${local.base_name}-kms-cw-flink-${var.application_name}"

  # Create-or-use branch for the CloudWatch Logs CMK. Empty string => default
  # CloudWatch-managed encryption (no customer key on the log group).
  cloudwatch_kms_key_arn = var.create_cloudwatch_kms_key ? aws_kms_key.cw[0].arn : var.cloudwatch_kms_key_arn

  # Create-or-use branch for the IAM execution role
  execution_role_arn = var.create_execution_role ? aws_iam_role.this[0].arn : var.service_execution_role_arn

  # KMS keys the execution role must use (Kinesis source + output buckets),
  # filtered to non-empty and de-duplicated.
  kms_usage_arns = distinct(compact(concat(
    [var.kinesis_stream_kms_key_arn],
    var.output_bucket_kms_key_arns
  )))
}
