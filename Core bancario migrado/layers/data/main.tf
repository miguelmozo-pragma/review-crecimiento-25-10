###############################################
# Gobierno: Data
# Ambiente: ALL
#
# Recursos:
#   - Aurora PostgreSQL (writer + reader opcional)
#   - ElastiCache Redis (replication group)
#   - S3 bucket (objetos)
#   - SSM Parameters con outputs del layer
###############################################

# ==========================================================================
# 1. Aurora PostgreSQL
# ==========================================================================
module "aurora" {
  source = "../../modules/aurora"
  providers = {
    aws.project = aws.project
  }

  project     = var.project
  environment = var.environment
  aws_region  = var.region

  cluster_name   = var.aurora_cluster_name
  engine_version = var.aurora_engine_version
  instance_class = var.aurora_instance_class
  database_name  = var.aurora_database_name

  vpc_id              = local.vpc_id
  subnet_ids          = local.data_subnet_ids
  allowed_cidr_blocks = local.db_allowed_cidrs

  create_read_replica = var.aurora_create_read_replica
  deletion_protection = var.aurora_deletion_protection

  additional_tags = var.common_tags
}

# ==========================================================================
# 2. ElastiCache Redis
# ==========================================================================
module "redis" {
  source = "../../modules/elasticache"
  providers = {
    aws.project = aws.project
  }

  project     = var.project
  environment = var.environment
  aws_region  = var.region

  name           = var.redis_name
  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type

  vpc_id              = local.vpc_id
  subnet_ids          = local.data_subnet_ids
  allowed_cidr_blocks = local.db_allowed_cidrs

  num_cache_clusters = var.redis_num_cache_clusters
  multi_az_enabled   = var.redis_multi_az_enabled

  additional_tags = var.common_tags
}

# ==========================================================================
# 3. S3 bucket (objetos)
# ==========================================================================
module "s3" {
  source = "../../modules/s3"
  providers = {
    aws.project = aws.project
  }

  project     = var.project
  environment = var.environment
  aws_region  = var.region

  bucket_name = var.s3_bucket_name

  additional_tags = var.common_tags
}

# ==========================================================================
# 4. Publicación de outputs en SSM Parameter Store
#    Patrón: /cb/{environment}/data/{recurso}
# ==========================================================================
resource "aws_ssm_parameter" "aurora_endpoint" {
  provider = aws.project
  name     = "/cb/${var.environment}/data/aurora-endpoint"
  type     = "String"
  value    = module.aurora.cluster_endpoint
  tags     = merge({ Name = "/cb/${var.environment}/data/aurora-endpoint" }, var.common_tags)
}

resource "aws_ssm_parameter" "aurora_reader_endpoint" {
  provider = aws.project
  name     = "/cb/${var.environment}/data/aurora-reader-endpoint"
  type     = "String"
  value    = module.aurora.reader_endpoint
  tags     = merge({ Name = "/cb/${var.environment}/data/aurora-reader-endpoint" }, var.common_tags)
}

resource "aws_ssm_parameter" "aurora_secret_arn" {
  provider = aws.project
  name     = "/cb/${var.environment}/data/aurora-secret-arn"
  type     = "String"
  value    = module.aurora.secret_arn
  tags     = merge({ Name = "/cb/${var.environment}/data/aurora-secret-arn" }, var.common_tags)
}

resource "aws_ssm_parameter" "redis_primary_endpoint" {
  provider = aws.project
  name     = "/cb/${var.environment}/data/redis-primary-endpoint"
  type     = "String"
  value    = module.redis.primary_endpoint_address
  tags     = merge({ Name = "/cb/${var.environment}/data/redis-primary-endpoint" }, var.common_tags)
}

resource "aws_ssm_parameter" "redis_reader_endpoint" {
  provider = aws.project
  name     = "/cb/${var.environment}/data/redis-reader-endpoint"
  type     = "String"
  value    = module.redis.reader_endpoint_address
  tags     = merge({ Name = "/cb/${var.environment}/data/redis-reader-endpoint" }, var.common_tags)
}

resource "aws_ssm_parameter" "s3_bucket_id" {
  provider = aws.project
  name     = "/cb/${var.environment}/data/s3-bucket-id"
  type     = "String"
  value    = module.s3.bucket_id
  tags     = merge({ Name = "/cb/${var.environment}/data/s3-bucket-id" }, var.common_tags)
}
