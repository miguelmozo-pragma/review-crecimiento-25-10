locals {
  base_name = "rtda-${var.environment}"

  # rtda-{env}-kinesis-{funcionalidad}  e.g. rtda-dev-kinesis-ingesta
  stream_name = "${local.base_name}-kinesis-${var.stream_name}"

  # rtda-{env}-kms-kinesis  (dedicated CMK for this service)
  kms_alias_name = "alias/${local.base_name}-kms-kinesis"

  # Create-or-use KMS branch centralized in a single local
  kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn

  # shard_count only applies in PROVISIONED mode
  shard_count = var.stream_mode == "PROVISIONED" ? coalesce(var.shard_count, 1) : null
}
