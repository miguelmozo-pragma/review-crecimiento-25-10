###############################################
# AGAT - Data - QA
# Aurora PostgreSQL (writer + reader)
###############################################

project     = "agat"
environment = "qa"
region      = "us-west-2"
profile     = ""

###############################################
# Aurora PostgreSQL (qa: mediana, writer + reader)
###############################################
aurora_cluster_name        = "core"
aurora_engine_version      = "15.10"
aurora_instance_class      = "db.r6g.large"
aurora_database_name       = "gestionadmin"
aurora_create_read_replica = true
aurora_deletion_protection = false

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Calidad"
  Proyecto         = "AGAT"
  Descripcion      = "Data - Aurora PostgreSQL - QA"
  Nombre           = "agat-qa-data"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "AGAT_Infraestructura_IaC"
}
