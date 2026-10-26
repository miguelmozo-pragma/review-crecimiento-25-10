###############################################
# Module: Lambda function
#
# Resources:
#   - IAM role + base policy (+ optional custom statements)
#   - Dedicated CloudWatch Logs CMK + log group (encrypted)
#   - Lambda function
#   - CloudWatch error alarm (optional)
###############################################

# ==========================================================================
# 0. Context
# ==========================================================================
data "aws_caller_identity" "current" {
  provider = aws.project
}

# ==========================================================================
# 1. IAM role
# ==========================================================================
resource "aws_iam_role" "this" {
  provider = aws.project
  count    = var.create_role ? 1 : 0

  name = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "LambdaAssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    { Name = local.role_name },
    var.additional_tags
  )
}

resource "aws_iam_role_policy" "base" {
  provider = aws.project
  count    = var.create_role ? 1 : 0

  name = "${local.policy_name}-base"
  role = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "CloudWatchLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "${aws_cloudwatch_log_group.this.arn}:*"
        }
      ],
      local.runs_in_vpc ? [
        {
          Sid    = "VPCNetworkInterfaces"
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface"
          ]
          Resource = "*"
        }
      ] : [],
      var.tracing_mode == "Active" ? [
        {
          Sid    = "XRayTracing"
          Effect = "Allow"
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords"
          ]
          Resource = "*"
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy" "custom" {
  provider = aws.project
  count    = var.create_role && length(var.policy_statements) > 0 ? 1 : 0

  name = "${local.policy_name}-custom"
  role = aws_iam_role.this[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for stmt in var.policy_statements : {
        Sid      = stmt.sid
        Effect   = stmt.effect
        Action   = stmt.actions
        Resource = stmt.resources
      }
    ]
  })
}

# ==========================================================================
# 2. CloudWatch logging (dedicated CMK + log group)
# ==========================================================================
data "aws_iam_policy_document" "cw_kms" {
  count    = var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

  statement {
    sid       = "EnableRootPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group}"]
    }
  }
}

resource "aws_kms_key" "cw" {
  count    = var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

  description             = "CMK for CloudWatch Logs of ${local.function_name}"
  deletion_window_in_days = var.cloudwatch_kms_deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = 365
  policy                  = data.aws_iam_policy_document.cw_kms[0].json

  tags = merge(
    { Name = "${local.base_name}-kms-cw-lambda-${var.function_name}" },
    var.additional_tags
  )
}

resource "aws_kms_alias" "cw" {
  count    = var.create_cloudwatch_kms_key ? 1 : 0
  provider = aws.project

  name          = local.cw_kms_alias_name
  target_key_id = aws_kms_key.cw[0].key_id
}

resource "aws_cloudwatch_log_group" "this" {
  provider = aws.project

  name              = local.log_group
  retention_in_days = var.log_retention_days
  kms_key_id        = local.cloudwatch_kms_key_arn != "" ? local.cloudwatch_kms_key_arn : null

  tags = merge(
    { Name = local.log_group },
    var.additional_tags
  )
}

# ==========================================================================
# 3. Lambda function
# ==========================================================================
#checkov:skip=CKV_AWS_272:Code signing not required for this deployment model
resource "aws_lambda_function" "this" {
  provider = aws.project

  function_name = local.function_name
  description   = var.description != "" ? var.description : "Lambda function ${var.function_name} for ${local.base_name}"
  role          = var.create_role ? aws_iam_role.this[0].arn : var.existing_role_arn

  # Packaging
  package_type = var.package_type
  runtime      = var.package_type == "Zip" ? var.runtime : null
  handler      = var.package_type == "Zip" ? var.handler : null
  s3_bucket    = var.package_type == "Zip" ? var.s3_bucket : null
  s3_key       = var.package_type == "Zip" ? var.s3_key : null
  filename     = var.package_type == "Zip" && var.s3_bucket == null ? var.filename : null
  image_uri    = var.package_type == "Image" ? var.image_uri : null

  # Configuration
  memory_size   = var.memory_size
  timeout       = var.timeout
  architectures = var.architectures
  layers        = var.package_type == "Zip" ? var.layers : null

  # Concurrency
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Encryption of environment variables
  kms_key_arn = var.kms_key_arn

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = local.runs_in_vpc ? [1] : []
    content {
      subnet_ids         = var.vpc_subnet_ids
      security_group_ids = var.vpc_security_group_ids
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  tracing_config {
    mode = var.tracing_mode
  }

  tags = merge(
    { Name = local.function_name },
    var.additional_tags
  )

  depends_on = [
    aws_iam_role_policy.base,
    aws_cloudwatch_log_group.this,
  ]

  # Code is deployed/updated outside Terraform (pipeline). Ignore drift on it.
  lifecycle {
    ignore_changes = [image_uri, filename, s3_key]
  }
}

# ==========================================================================
# 4. CloudWatch error alarm (optional)
# ==========================================================================
resource "aws_cloudwatch_metric_alarm" "errors" {
  provider = aws.project
  count    = var.create_alarm ? 1 : 0

  alarm_name          = "${local.alarm_name}-errors"
  alarm_description   = "Alarm for Lambda ${local.function_name} errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period
  statistic           = "Sum"
  threshold           = var.alarm_error_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions

  tags = merge(
    { Name = "${local.alarm_name}-errors" },
    var.additional_tags
  )
}
