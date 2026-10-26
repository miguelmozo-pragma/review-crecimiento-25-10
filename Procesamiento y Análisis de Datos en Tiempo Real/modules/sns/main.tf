###############################################
# Module: SNS topic
#
# Resources:
#   - Dedicated KMS CMK (sns) + alias
#   - SNS topic (SSE-KMS)
#   - Topic access policy (optional / least-privilege publishers)
#   - Subscriptions
###############################################

# ==========================================================================
# 0. Context
# ==========================================================================
data "aws_caller_identity" "current" {
  provider = aws.project
}

# ==========================================================================
# 1. Dedicated KMS CMK for SNS
# ==========================================================================
resource "aws_kms_key" "this" {
  count    = var.create_kms_key ? 1 : 0
  provider = aws.project

  description             = "CMK for SNS topic ${local.topic_name}"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365

  tags = merge(
    { Name = "${local.base_name}-kms-sns-${var.topic_name}" },
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
# 2. SNS topic
# ==========================================================================
resource "aws_sns_topic" "this" {
  provider = aws.project

  name         = var.fifo_topic ? "${local.topic_name}.fifo" : local.topic_name
  display_name = var.display_name != "" ? var.display_name : local.topic_name
  fifo_topic   = var.fifo_topic

  # Encryption at rest with the dedicated CMK
  kms_master_key_id = local.kms_key_id

  tags = merge(
    { Name = local.topic_name },
    var.additional_tags
  )
}

# ==========================================================================
# 3. Topic access policy
#    Custom policy wins; otherwise build a least-privilege publisher policy
#    when allowed_publisher_arns is provided.
# ==========================================================================
data "aws_iam_policy_document" "publishers" {
  count    = var.topic_policy == null && length(var.allowed_publisher_arns) > 0 ? 1 : 0
  provider = aws.project

  statement {
    sid       = "AllowPublishers"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]
    principals {
      type        = "AWS"
      identifiers = var.allowed_publisher_arns
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  count    = var.topic_policy != null || length(var.allowed_publisher_arns) > 0 ? 1 : 0
  provider = aws.project

  arn    = aws_sns_topic.this.arn
  policy = var.topic_policy != null ? var.topic_policy : data.aws_iam_policy_document.publishers[0].json
}

# ==========================================================================
# 4. Subscriptions
# ==========================================================================
resource "aws_sns_topic_subscription" "this" {
  for_each = local.subscriptions
  provider = aws.project

  topic_arn            = aws_sns_topic.this.arn
  protocol             = each.value.protocol
  endpoint             = each.value.endpoint
  raw_message_delivery = each.value.raw_message_delivery
  filter_policy        = each.value.filter_policy
}
