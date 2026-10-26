###############################################
# Core_Bancario - Data - QA
# Aurora PostgreSQL + ElastiCache Redis + S3
###############################################

project     = "cb"
environment = "qa"
region      = "us-west-2"
profile     = ""

###############################################
# Aurora PostgreSQL (qa: mediana, writer + reader)
###############################################
aurora_cluster_name        = "core"
aurora_engine_version      = "15.10"
aurora_instance_class      = "db.r6g.large"
aurora_database_name       = "corebancario"
aurora_create_read_replica = true
aurora_deletion_protection = false

###############################################
# ElastiCache Redis (qa: mediano, multi-AZ, primary + replica)
###############################################
redis_name               = "core"
redis_engine_version     = "7.1"
redis_node_type          = "cache.t4g.medium"
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
  Ambiente         = "Calidad"
  Proyecto         = "Core_Bancario"
  Descripcion      = "Data - Aurora Redis y S3 - QA"
  Nombre           = "cb-qa-data"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
