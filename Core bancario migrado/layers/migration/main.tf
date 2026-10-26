###############################################
# Gobierno: Migration
# Ambiente: ALL
#
# Recursos:
#   - DMS (module): replication instance, endpoints, task, KMS, secret, SG
#   - DataSync VPC endpoint (interface) + SG
#   - SSM Parameters con outputs del layer
###############################################

# ==========================================================================
# 1. DMS (PostgreSQL on-prem -> Aurora)
# ==========================================================================
module "dms" {
  source = "../../modules/dms"
  providers = {
    aws.project = aws.project
  }

  project     = var.project
  environment = var.environment
  aws_region  = var.region

  name = var.dms_name

  vpc_id              = local.vpc_id
  subnet_ids          = local.data_subnet_ids
  allowed_cidr_blocks = [local.vpc_cidr]

  replication_instance_class = var.dms_replication_instance_class
  engine_version             = var.dms_engine_version
  migration_type             = var.dms_migration_type

  # Source (on-prem PostgreSQL)
  source_server_name   = var.dms_source_server_name
  source_database_name = var.dms_source_database_name
  source_username      = var.dms_source_username
  source_password      = var.dms_source_password

  # Target (Aurora)
  target_server_name   = var.dms_target_server_name
  target_database_name = var.dms_target_database_name
  target_username      = var.dms_target_username
  target_password      = var.dms_target_password

  # No arrancar la task automáticamente; se inicia manualmente tras validar
  start_replication_task = false

  additional_tags = var.common_tags
}

# ==========================================================================
# 2. DataSync VPC endpoint (interface) + Security Group
#    El agente DataSync on-prem apunta a este endpoint privado.
# ==========================================================================
resource "aws_security_group" "datasync" {
  provider = aws.project

  name        = local.datasync_sg_name
  description = "Security group for the DataSync VPC interface endpoint"
  vpc_id      = local.vpc_id

  tags = merge(
    { Name = local.datasync_sg_name },
    var.common_tags
  )
}

# Ingress: el agente DataSync on-prem se conecta al endpoint.
# DataSync usa 443 (control) y 1024-1064 (data transfer) hacia el endpoint.
resource "aws_security_group_rule" "datasync_ingress_https" {
  provider          = aws.project
  type              = "ingress"
  security_group_id = aws_security_group.datasync.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [local.vpc_cidr]
  description       = "HTTPS control traffic from the on-prem DataSync agent (via VPN/DX into the VPC)"
}

resource "aws_security_group_rule" "datasync_ingress_data" {
  provider          = aws.project
  type              = "ingress"
  security_group_id = aws_security_group.datasync.id
  from_port         = 1024
  to_port           = 1064
  protocol          = "tcp"
  cidr_blocks       = [local.vpc_cidr]
  description       = "Data transfer traffic from the on-prem DataSync agent"
}

resource "aws_security_group_rule" "datasync_egress_all" {
  provider          = aws.project
  type              = "egress"
  security_group_id = aws_security_group.datasync.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress"
}

resource "aws_vpc_endpoint" "datasync" {
  provider = aws.project

  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.region}.datasync"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.data_subnet_ids
  security_group_ids  = [aws_security_group.datasync.id]
  private_dns_enabled = true

  tags = merge(
    { Name = local.datasync_endpoint_name },
    var.common_tags
  )
}

# ==========================================================================
# 3. Publicación de outputs en SSM Parameter Store
#    Patrón: /cb/{environment}/migration/{recurso}
# ==========================================================================
resource "aws_ssm_parameter" "dms_replication_instance_arn" {
  provider = aws.project
  name     = "/cb/${var.environment}/migration/dms-replication-instance-arn"
  type     = "String"
  value    = module.dms.replication_instance_arn
  tags     = merge({ Name = "/cb/${var.environment}/migration/dms-replication-instance-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "datasync_vpc_endpoint_id" {
  provider = aws.project
  name     = "/cb/${var.environment}/migration/datasync-vpc-endpoint-id"
  type     = "String"
  value    = aws_vpc_endpoint.datasync.id
  tags     = merge({ Name = "/cb/${var.environment}/migration/datasync-vpc-endpoint-id" }, var.common_tags)
}
