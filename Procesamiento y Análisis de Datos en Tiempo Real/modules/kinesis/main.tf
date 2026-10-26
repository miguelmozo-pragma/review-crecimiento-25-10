###############################################
# Module: Kinesis Data Stream
#
# Resources:
#   - KMS CMK dedicated to Kinesis (optional, create-or-use)
#   - KMS alias
#   - Kinesis Data Stream (encryption at rest with CMK)
###############################################

# ==========================================================================
# 1. KMS Customer Managed Key (dedicated to Kinesis)
# ==========================================================================
resource "aws_kms_key" "this" {
  count    = var.create_kms_key ? 1 : 0
  provider = aws.project

  description             = "CMK for Kinesis Data Stream ${local.stream_name}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365

  tags = merge(
    { Name = "${local.base_name}-kms-kinesis" },
    var.additional_tags
  )
}

resource "aws_kms_alias" "this" {
  count    = var.create_kms_key ? 1 : 0
  provider = aws.project

  name          = local.kms_alias_name
  target_key_id = aws_kms_key.this[0].key_id
}

# ==========================================================================
# 2. Kinesis Data Stream
# ==========================================================================
resource "aws_kinesis_stream" "this" {
  provider = aws.project

  name             = local.stream_name
  retention_period = var.retention_period
  shard_count      = local.shard_count

  stream_mode_details {
    stream_mode = var.stream_mode
  }

  # Encryption at rest with the dedicated CMK (never AWS-owned key)
  encryption_type = "KMS"
  kms_key_id      = local.kms_key_arn

  shard_level_metrics = var.shard_level_metrics

  tags = merge(
    { Name = local.stream_name },
    var.additional_tags
  )
}
