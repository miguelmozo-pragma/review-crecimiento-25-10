###############################################
# Core_Bancario - Data - Dev
# Aurora PostgreSQL + ElastiCache Redis + S3
###############################################

project     = "cb"
environment = "dev"
region      = "us-west-2"
profile     = ""

###############################################
# Aurora PostgreSQL (dev: pequeña, solo writer)
###############################################
aurora_cluster_name        = "core"
aurora_engine_version      = "15.10"
aurora_instance_class      = "db.t4g.medium"
aurora_database_name       = "corebancario"
aurora_create_read_replica = false
aurora_deletion_protection = false

###############################################
# ElastiCache Redis (dev: pequeño, single-node)
###############################################
redis_name               = "core"
redis_engine_version     = "7.1"
redis_node_type          = "cache.t4g.micro"
redis_num_cache_clusters = 1
redis_multi_az_enabled   = false

###############################################
# S3
###############################################
s3_bucket_name = "objetos"

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Desarrollo"
  Proyecto         = "Core_Bancario"
  Descripcion      = "Data - Aurora Redis y S3 - Dev"
  Nombre           = "cb-dev-data"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
