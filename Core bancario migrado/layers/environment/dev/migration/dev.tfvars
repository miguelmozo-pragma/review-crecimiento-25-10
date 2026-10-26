###############################################
# Core_Bancario - Migration - Dev
# DMS (on-prem PostgreSQL -> Aurora) + DataSync VPC endpoint
#
# NOTA: las passwords (dms_source_password, dms_target_password) NO van en
# este archivo. Inyectarlas al aplicar con -var o TF_VAR_.
###############################################

project     = "cb"
environment = "dev"
region      = "us-west-2"
profile     = ""

###############################################
# DMS
###############################################
dms_name                       = "core"
dms_replication_instance_class = "dms.t3.medium"
dms_engine_version             = "3.5.4"
dms_migration_type             = "full-load"

# Source: PostgreSQL on-prem (ajustar al servidor real)
dms_source_server_name   = "10.1.0.10"
dms_source_database_name = "corebancario"
dms_source_username      = "dms_migrator"

# Target: Aurora writer endpoint (del layer data) - actualizar tras crear Aurora
dms_target_server_name   = "cb-dev-aurora-core.cluster-placeholder.us-west-2.rds.amazonaws.com"
dms_target_database_name = "corebancario"
dms_target_username      = "cbadmin"

###############################################
# DataSync
###############################################
datasync_name = "core"

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Desarrollo"
  Proyecto         = "Core_Bancario"
  Descripcion      = "Migration - DMS y DataSync - Dev"
  Nombre           = "cb-dev-migration"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
