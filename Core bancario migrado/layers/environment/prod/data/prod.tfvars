###############################################
# Core_Bancario - Data - Prod
# Aurora PostgreSQL + ElastiCache Redis + S3
###############################################

project     = "cb"
environment = "prod"
region      = "us-west-2"
profile     = ""

###############################################
# Aurora PostgreSQL (prod: instancia grande, writer + reader)
###############################################
aurora_cluster_name        = "core"
aurora_engine_version      = "15.10"
aurora_instance_class      = "db.r6g.xlarge"
aurora_database_name       = "corebancario"
aurora_create_read_replica = true
aurora_deletion_protection = false

###############################################
# ElastiCache Redis (prod: grande, multi-AZ, primary + replica)
###############################################
redis_name               = "core"
redis_engine_version     = "7.1"
redis_node_type          = "cache.r6g.large"
redis_num_cache_clusters = 2
redis_multi_az_enabled   = true

###############################################
# S3
###############################################
s3_bucket_name = "objetos"

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Produccion"
  Proyecto         = "Core_Bancario"
  Descripcion      = "Data - Aurora Redis y S3 - Prod"
  Nombre           = "cb-prod-data"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
