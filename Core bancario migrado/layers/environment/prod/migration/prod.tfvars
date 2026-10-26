###############################################
# Core_Bancario - Migration - Prod
# DMS (on-prem PostgreSQL -> Aurora) + DataSync VPC endpoint
#
# NOTA: las passwords (dms_source_password, dms_target_password) NO van en
# este archivo. Inyectarlas al aplicar con -var o TF_VAR_:
#   TF_VAR_dms_source_password=... TF_VAR_dms_target_password=... terraform apply ...
###############################################

project     = "cb"
environment = "prod"
region      = "us-west-2"
profile     = ""

###############################################
# DMS
###############################################
dms_name                       = "core"
dms_replication_instance_class = "dms.r6i.large"
dms_engine_version             = "3.5.4"
dms_migration_type             = "full-load-and-cdc"

# Source: PostgreSQL on-prem (ajustar al servidor real / alcanzable vía VPN/DX)
dms_source_server_name   = "10.1.0.10"
dms_source_database_name = "corebancario"
dms_source_username      = "dms_migrator"

# Target: Aurora writer endpoint (del layer data)
dms_target_server_name   = "cb-prod-aurora-core.cluster-cvmgc2ceyuyj.us-west-2.rds.amazonaws.com"
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
  Ambiente         = "Produccion"
  Proyecto         = "Core_Bancario"
  Descripcion      = "Migration - DMS y DataSync - Prod"
  Nombre           = "cb-prod-migration"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
