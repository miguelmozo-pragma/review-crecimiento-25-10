###########################################
# Aurora PostgreSQL cluster (writer + optional reader)
###########################################

data "aws_caller_identity" "current" {
  provider = aws.project
}

# ==========================================================================
# KMS: dedicated CMK created only when no external key ARN is provided.
# ==========================================================================
resource "aws_kms_key" "aurora" {
  provider = aws.project
  count    = local.create_kms ? 1 : 0

  description             = local.kms_key_desc
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
    { Name = "${local.base_name}-kms-aurora-${var.cluster_name}" },
    var.additional_tags
  )
}

resource "aws_kms_alias" "aurora" {
  provider = aws.project
  count    = local.create_kms ? 1 : 0

  name          = local.kms_alias_name
  target_key_id = aws_kms_key.aurora[0].key_id
}

# ==========================================================================
# Networking: DB subnet group + security group (private, no public access).
# ==========================================================================
resource "aws_db_subnet_group" "this" {
  provider = aws.project

  name       = local.subnet_group_name
  subnet_ids = var.subnet_ids

  tags = merge(
    { Name = local.subnet_group_name },
    var.additional_tags
  )
}

resource "aws_security_group" "aurora" {
  provider = aws.project

  name        = local.sg_name
  description = "Security group for Aurora PostgreSQL ${local.cluster_name}"
  vpc_id      = var.vpc_id

  tags = merge(
    { Name = local.sg_name },
    var.additional_tags
  )
}

resource "aws_security_group_rule" "ingress_sg" {
  provider = aws.project
  count    = length(var.allowed_security_group_ids)

  description              = "PostgreSQL access from allowed security group"
  type                     = "ingress"
  from_port                = local.port
  to_port                  = local.port
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.aurora.id
}

resource "aws_security_group_rule" "ingress_cidr" {
  provider = aws.project
  count    = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  description       = "PostgreSQL access from allowed CIDR blocks"
  type              = "ingress"
  from_port         = local.port
  to_port           = local.port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.aurora.id
}

resource "aws_security_group_rule" "egress_all" {
  provider = aws.project
  # checkov:skip=CKV_AWS_382: Egreso total requerido para alcanzar servicios dependientes (KMS, S3, etc.) via VPC endpoints/NAT
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.aurora.id
}

# ==========================================================================
# Credentials: random master password + Secrets Manager secret (KMS-encrypted).
# ==========================================================================
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?." # excludes / @ " ' \ and space
}

resource "aws_secretsmanager_secret" "aurora" {
  provider = aws.project

  name       = local.secret_name
  kms_key_id = local.kms_key_arn

  tags = merge(
    { Name = local.secret_name },
    var.additional_tags
  )
}

resource "aws_secretsmanager_secret_version" "aurora" {
  provider = aws.project

  secret_id = aws_secretsmanager_secret.aurora.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "aurora-postgresql"
    host     = aws_rds_cluster.this.endpoint
    port     = local.port
    dbname   = var.database_name
  })
}

# ==========================================================================
# Aurora cluster.
# ==========================================================================
resource "aws_rds_cluster" "this" {
  provider = aws.project
  # checkov:skip=CKV_AWS_139: La protección de borrado es configurable via var.deletion_protection por ambiente
  # checkov:skip=CKV2_AWS_8: El backup se gestiona con backup_retention_period; backup plan a nivel de cuenta
  # checkov:skip=CKV_AWS_313: Logs de auditoria se habilitan a nivel de parameter group en iteracion posterior

  cluster_identifier = local.cluster_name
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version

  database_name   = var.database_name
  master_username = var.master_username
  master_password = random_password.master.result
  port            = local.port

  storage_encrypted = true
  kms_key_id        = local.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "03:00-04:00"

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.cluster_name}-final"
  apply_immediately         = var.apply_immediately

  tags = merge(
    { Name = local.cluster_name },
    var.additional_tags
  )
}

# ==========================================================================
# Cluster instances: writer always, reader when create_read_replica is true.
# ==========================================================================
resource "aws_rds_cluster_instance" "writer" {
  provider = aws.project
  count    = 1

  identifier         = local.writer_name
  cluster_identifier = aws_rds_cluster.this.id
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  instance_class     = var.instance_class

  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = false

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? local.kms_key_arn : null

  tags = merge(
    { Name = local.writer_name },
    var.additional_tags
  )
}

resource "aws_rds_cluster_instance" "reader" {
  provider = aws.project
  count    = var.create_read_replica ? 1 : 0

  identifier         = local.reader_name
  cluster_identifier = aws_rds_cluster.this.id
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  instance_class     = var.instance_class

  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = false

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? local.kms_key_arn : null

  tags = merge(
    { Name = local.reader_name },
    var.additional_tags
  )
}
