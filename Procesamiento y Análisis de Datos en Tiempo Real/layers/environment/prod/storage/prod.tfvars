###############################################
# RTDA - Storage - Prod
# Data Lake: buckets S3 (raw + datalake) + Lake Formation
###############################################

project     = "rtda"
environment = "prod"
region      = "us-west-2"
profile     = ""

# --- Bucket RAW ---
raw_bucket_name        = "raw"
raw_force_destroy      = false
raw_versioning_enabled = true
raw_lifecycle_rules = [
  {
    id                                 = "raw-transition-expire"
    enabled                            = true
    prefix                             = ""
    expiration_days                    = 1095
    noncurrent_version_expiration_days = 90
    transition = [
      {
        days          = 90
        storage_class = "STANDARD_IA"
      },
      {
        days          = 180
        storage_class = "GLACIER"
      }
    ]
  }
]

# --- Bucket DATA LAKE ---
datalake_bucket_name        = "datalake"
datalake_force_destroy      = false
datalake_versioning_enabled = true
datalake_lifecycle_rules = [
  {
    id                                 = "datalake-transition"
    enabled                            = true
    prefix                             = ""
    expiration_days                    = 1825
    noncurrent_version_expiration_days = 90
    transition = [
      {
        days          = 90
        storage_class = "STANDARD_IA"
      }
    ]
  }
]

# --- Lake Formation ---
database_name             = "datalake"
manage_data_lake_settings = false
use_service_linked_role   = true
data_lake_admins          = []
database_permissions      = []
table_permissions         = []

# Tags corporativos
common_tags = {
  Ambiente    = "Produccion"
  Proyecto    = "RTDA"
  Descripcion = "Data Lake storage - Prod"
  Nombre      = "rtda-prod-storage"
  ManagedBy   = "terraform"
}
