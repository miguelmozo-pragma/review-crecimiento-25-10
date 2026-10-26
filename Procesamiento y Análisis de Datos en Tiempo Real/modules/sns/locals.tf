locals {
  base_name = "rtda-${var.environment}"

  # rtda-{env}-sns-{funcionalidad}  e.g. rtda-dev-sns-fraude
  topic_name = "${local.base_name}-sns-${var.topic_name}"

  # rtda-{env}-kms-sns  (dedicated CMK for SNS)
  kms_alias_name = "alias/${local.base_name}-kms-sns-${var.topic_name}"

  # Create-or-use KMS branch centralized in a single local.
  kms_key_id = var.create_kms_key ? aws_kms_key.this[0].key_id : var.kms_key_id

  # Normalize subscriptions into a map keyed by protocol+endpoint for for_each
  subscriptions = {
    for s in var.subscriptions :
    "${s.protocol}::${s.endpoint}" => s
  }
}
