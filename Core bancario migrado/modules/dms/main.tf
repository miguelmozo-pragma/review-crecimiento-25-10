###########################################
########### KMS (opcional) ################
###########################################

resource "aws_kms_key" "this" {
  provider = aws.project
  count    = local.create_kms ? 1 : 0

  description             = "KMS key for DMS ${local.replication_instance_id}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    { Name = "${local.base_name}-kms-dms-${var.name}" },
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
########### Security Group ################
###########################################

resource "aws_security_group" "this" {
  provider = aws.project

  name        = local.sg_name
  description = "Security group for DMS replication instance ${local.replication_instance_id}"
  vpc_id      = var.vpc_id

  tags = merge(
    { Name = local.sg_name },
    var.additional_tags
  )
}

resource "aws_security_group_rule" "egress_all" {
  provider          = aws.project
  type              = "egress"
  security_group_id = aws_security_group.this.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress (reach source and target databases)"
}

resource "aws_security_group_rule" "ingress_cidr" {
  provider          = aws.project
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  security_group_id = aws_security_group.this.id
  from_port         = var.target_port
  to_port           = var.target_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Allow DB port ingress from allowed CIDR blocks"
}

###########################################
########### Secret (credenciales) #########
###########################################

resource "aws_secretsmanager_secret" "this" {
  provider = aws.project

  name        = local.secret_name
  description = "DMS source/target credentials for ${local.replication_instance_id}"
  kms_key_id  = local.kms_key_arn

  tags = merge(
    { Name = local.secret_name },
    var.additional_tags
  )
}

resource "aws_secretsmanager_secret_version" "this" {
  provider  = aws.project
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    source = {
      server_name   = var.source_server_name
      port          = var.source_port
      database_name = var.source_database_name
      username      = var.source_username
      password      = var.source_password
    }
    target = {
      server_name   = var.target_server_name
      port          = var.target_port
      database_name = var.target_database_name
      username      = var.target_username
      password      = var.target_password
    }
  })
}

###########################################
########### DMS VPC service role ##########
# Rol de servicio con nombre fijo requerido por DMS para gestionar recursos
# de red (ENIs, subnets). Es un rol a nivel de cuenta, compartido entre
# ambientes. Crear solo si no existe (create_dms_vpc_role).
###########################################

resource "aws_iam_role" "dms_vpc_role" {
  provider = aws.project
  count    = var.create_dms_vpc_role ? 1 : 0

  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    { Name = "dms-vpc-role" },
    var.additional_tags
  )
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role" {
  provider   = aws.project
  count      = var.create_dms_vpc_role ? 1 : 0
  role       = aws_iam_role.dms_vpc_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

###########################################
########### Replication subnet group ######
###########################################

resource "aws_dms_replication_subnet_group" "this" {
  provider = aws.project

  replication_subnet_group_id          = local.subnet_group_id
  replication_subnet_group_description = "DMS subnet group for ${local.replication_instance_id}"
  subnet_ids                           = var.subnet_ids

  tags = merge(
    { Name = local.subnet_group_id },
    var.additional_tags
  )

  # El subnet group requiere que dms-vpc-role exista previamente
  depends_on = [aws_iam_role_policy_attachment.dms_vpc_role]
}

###########################################
########### Replication instance ##########
###########################################

resource "aws_dms_replication_instance" "this" {
  provider = aws.project

  replication_instance_id     = local.replication_instance_id
  replication_instance_class  = var.replication_instance_class
  allocated_storage           = var.allocated_storage
  engine_version              = var.engine_version
  multi_az                    = var.multi_az
  publicly_accessible         = var.publicly_accessible
  kms_key_arn                 = local.kms_key_arn
  replication_subnet_group_id = aws_dms_replication_subnet_group.this.id
  vpc_security_group_ids      = [aws_security_group.this.id]

  tags = merge(
    { Name = local.replication_instance_id },
    var.additional_tags
  )
}

###########################################
########### Endpoints #####################
###########################################

resource "aws_dms_endpoint" "source" {
  provider = aws.project

  endpoint_id   = local.source_endpoint_id
  endpoint_type = "source"
  engine_name   = var.source_engine_name
  server_name   = var.source_server_name
  port          = var.source_port
  database_name = var.source_database_name
  username      = var.source_username
  password      = var.source_password
  kms_key_arn   = local.kms_key_arn

  tags = merge(
    { Name = local.source_endpoint_id },
    var.additional_tags
  )
}

resource "aws_dms_endpoint" "target" {
  provider = aws.project

  endpoint_id   = local.target_endpoint_id
  endpoint_type = "target"
  engine_name   = var.target_engine_name
  server_name   = var.target_server_name
  port          = var.target_port
  database_name = var.target_database_name
  username      = var.target_username
  password      = var.target_password
  kms_key_arn   = local.kms_key_arn

  tags = merge(
    { Name = local.target_endpoint_id },
    var.additional_tags
  )
}

###########################################
########### Replication task ##############
###########################################

resource "aws_dms_replication_task" "this" {
  provider = aws.project

  replication_task_id      = local.task_id
  migration_type           = var.migration_type
  replication_instance_arn = aws_dms_replication_instance.this.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn
  table_mappings           = local.table_mappings

  start_replication_task = var.start_replication_task

  tags = merge(
    { Name = local.task_id },
    var.additional_tags
  )
}
