###########################################
# IRSA IAM role (IAM Role for Service Account)
###########################################

resource "aws_iam_role" "irsa" {
  provider = aws.project

  name = local.irsa_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSIRSA"
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${local.service_account_name}"
            "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    { Name = local.irsa_role_name },
    var.additional_tags
  )
}

resource "aws_iam_role_policy" "irsa" {
  provider = aws.project
  count    = length(var.policy_statements) > 0 ? 1 : 0

  name = local.irsa_policy_name
  role = aws_iam_role.irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for s in var.policy_statements : {
        Sid      = s.sid
        Effect   = s.effect
        Action   = s.actions
        Resource = s.resources
      }
    ]
  })
}
