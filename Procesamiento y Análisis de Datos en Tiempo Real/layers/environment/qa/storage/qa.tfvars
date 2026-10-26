###############################################
# RTDA - Storage - QA
# Data Lake: buckets S3 (raw + datalake) + Lake Formation
###############################################

project     = "rtda"
environment = "qa"
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
    expiration_days                    = 365
    noncurrent_version_expiration_days = 60
    transition = [
      {
        days          = 60
        storage_class = "STANDARD_IA"
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
    expiration_days                    = 1095
    noncurrent_version_expiration_days = 60
    transition = [
      {
        days          = 60
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
  Ambiente    = "Calidad"
  Proyecto    = "RTDA"
  Descripcion = "Data Lake storage - QA"
  Nombre      = "rtda-qa-storage"
  ManagedBy   = "terraform"
}
