###########################################
# Module: ElastiCache Redis (cluster-mode-disabled)
#
# Creates a Redis replication group with:
# - Dedicated KMS CMK (only when no kms_key_arn is passed)
# - Private subnet group + restricted security group (6379 only)
# - Encryption at rest (CMK) and in transit (TLS) always enabled
#
# Notes:
# - num_cache_clusters is the total node count (1 primary + (N-1) replicas).
#   default 2 = 1 primary + 1 replica.
# - Parameter group is intentionally omitted: Redis 7.1 uses the AWS default
#   (default.redis7); no custom tuning is required here.
# - auth_token is recommended for prod; left null (not configured) otherwise.
###########################################

###########################################
# Data sources + dedicated KMS CMK
###########################################

data "aws_caller_identity" "current" {
  provider = aws.project
}

resource "aws_kms_key" "this" {
  provider = aws.project
  count    = local.create_kms ? 1 : 0

  description             = "KMS CMK for ElastiCache Redis ${local.replication_group_id}"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })

  tags = merge(
    { Name = local.kms_key_name },
    var.additional_tags
  )
}

resource "aws_kms_alias" "this" {
  provider = aws.project
  count    = local.create_kms ? 1 : 0

  name          = local.kms_alias
  target_key_id = aws_kms_key.this[0].key_id
}

###########################################
# Networking: subnet group + security group
###########################################

resource "aws_elasticache_subnet_group" "this" {
  provider = aws.project

  name        = local.subnet_group_name
  description = "Private subnets for ${local.replication_group_id}"
  subnet_ids  = var.subnet_ids

  tags = merge(
    { Name = local.subnet_group_name },
    var.additional_tags
  )
}

resource "aws_security_group" "this" {
  provider = aws.project

  name        = local.sg_name
  description = "Redis 6379 access for ${local.replication_group_id}"
  vpc_id      = var.vpc_id

  # Ingress from allowed security groups (one rule per SG; empty list = no rule)
  dynamic "ingress" {
    for_each = toset(var.allowed_security_group_ids)
    content {
      from_port       = 6379
      to_port         = 6379
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "Redis from allowed SG"
    }
  }

  # Ingress from allowed CIDR blocks (single rule; empty list = no rule)
  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "Redis from allowed CIDRs"
    }
  }

  egress {
    # checkov:skip=CKV_AWS_382: Egress abierto requerido para DNS/healthchecks del cluster; ingress está restringido a 6379
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    { Name = local.sg_name },
    var.additional_tags
  )
}

###########################################
# Redis replication group (cluster-mode-disabled)
###########################################

resource "aws_elasticache_replication_group" "this" {
  provider = aws.project

  replication_group_id = local.replication_group_id
  description          = "Core Bancario Redis - ${var.name} (${var.environment})"

  engine         = "redis"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  # cluster-mode-disabled: num_cache_clusters = total nodes (1 primary + (N-1) replicas)
  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = local.effective_failover
  multi_az_enabled           = local.effective_multi_az

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = local.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = var.auth_token

  snapshot_retention_limit = var.snapshot_retention_limit
  maintenance_window       = var.maintenance_window
  apply_immediately        = var.apply_immediately

  tags = merge(
    { Name = local.replication_group_id },
    var.additional_tags
  )
}
