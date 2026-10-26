###############################################
# AGAT - Data - Prod
# Aurora PostgreSQL (writer + reader)
###############################################

project     = "agat"
environment = "prod"
region      = "us-west-2"
profile     = ""

###############################################
# Aurora PostgreSQL (prod: instancia grande, writer + reader)
###############################################
aurora_cluster_name        = "core"
aurora_engine_version      = "15.10"
aurora_instance_class      = "db.r6g.xlarge"
aurora_database_name       = "gestionadmin"
aurora_create_read_replica = true
aurora_deletion_protection = true

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Produccion"
  Proyecto         = "AGAT"
  Descripcion      = "Data - Aurora PostgreSQL - Prod"
  Nombre           = "agat-prod-data"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "AGAT_Infraestructura_IaC"
}
