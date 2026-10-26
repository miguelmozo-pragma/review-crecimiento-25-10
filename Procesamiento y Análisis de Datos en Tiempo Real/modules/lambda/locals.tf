locals {
  base_name = "rtda-${var.environment}"

  # rtda-{env}-lambda-{funcionalidad}  e.g. rtda-dev-lambda-evento-fraude
  function_name = "${local.base_name}-lambda-${var.function_name}"
  role_name     = "${local.base_name}-lambda-${var.function_name}-role"
  policy_name   = "${local.base_name}-lambda-${var.function_name}"
  log_group     = "/aws/lambda/${local.function_name}"
  alarm_name    = "${local.base_name}-lambda-${var.function_name}"

  # Dedicated CloudWatch Logs CMK: rtda-{env}-kms-cw-lambda-{funcionalidad}
  cw_kms_alias_name = "alias/${local.base_name}-kms-cw-lambda-${var.function_name}"

  cloudwatch_kms_key_arn = var.create_cloudwatch_kms_key ? aws_kms_key.cw[0].arn : var.cloudwatch_log_kms_key_arn

  # Whether the function runs inside a VPC
  runs_in_vpc = length(var.vpc_subnet_ids) > 0
}
