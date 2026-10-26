###############################################
# AGAT - Data - Dev
# Aurora PostgreSQL (solo writer)
###############################################

project     = "agat"
environment = "dev"
region      = "us-west-2"
profile     = ""

###############################################
# Aurora PostgreSQL (dev: pequeña, solo writer)
###############################################
aurora_cluster_name        = "core"
aurora_engine_version      = "15.10"
aurora_instance_class      = "db.t4g.medium"
aurora_database_name       = "gestionadmin"
aurora_create_read_replica = false
aurora_deletion_protection = false

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Desarrollo"
  Proyecto         = "AGAT"
  Descripcion      = "Data - Aurora PostgreSQL - Dev"
  Nombre           = "agat-dev-data"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "AGAT_Infraestructura_IaC"
}
