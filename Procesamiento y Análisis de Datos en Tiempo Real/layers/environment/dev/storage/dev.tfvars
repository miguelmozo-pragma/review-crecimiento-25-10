###############################################
# RTDA - Storage - Dev
# Data Lake: buckets S3 (raw + datalake) + Lake Formation
###############################################

project     = "rtda"
environment = "dev"
region      = "us-west-2"
profile     = ""

# --- Bucket RAW ---
raw_bucket_name        = "raw"
raw_force_destroy      = true
raw_versioning_enabled = true
raw_lifecycle_rules = [
  {
    id                                 = "raw-transition-expire"
    enabled                            = true
    prefix                             = ""
    expiration_days                    = 365
    noncurrent_version_expiration_days = 30
    transition = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      }
    ]
  }
]

# --- Bucket DATA LAKE ---
datalake_bucket_name        = "datalake"
datalake_force_destroy      = true
datalake_versioning_enabled = true
datalake_lifecycle_rules = [
  {
    id                                 = "datalake-transition"
    enabled                            = true
    prefix                             = ""
    expiration_days                    = 730
    noncurrent_version_expiration_days = 30
    transition = [
      {
        days          = 30
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
  Ambiente    = "Desarrollo"
  Proyecto    = "RTDA"
  Descripcion = "Data Lake storage - Dev"
  Nombre      = "rtda-dev-storage"
  ManagedBy   = "terraform"
}
