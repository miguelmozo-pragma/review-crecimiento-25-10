###############################################
# AGAT - Workload - Prod
# Cluster EKS + addons (ALB Controller, EBS CSI, Karpenter)
###############################################

project     = "agat"
environment = "prod"
region      = "us-west-2"
profile     = ""

###############################################
# EKS
###############################################
cluster_name    = "core"
cluster_version = "1.31"

# Acceso al endpoint: público habilitado para pruebas (kubectl desde local).
# En producción real se recomienda dejar solo acceso privado.
cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

###############################################
# Node groups administrados (base del sistema)
# Corren coredns, lb-controller y el propio Karpenter.
# El escalado de cargas lo maneja Karpenter.
###############################################
node_groups = {
  system = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    min_size       = 1
    max_size       = 1
    desired_size   = 1
    disk_size      = 30
    labels = {
      role = "system"
    }
  }
}

###############################################
# Addons
###############################################
enable_lb_controller = true
ebs_csi_driver       = true

###############################################
# Karpenter
###############################################
enable_karpenter            = true
karpenter_chart_version     = "1.8.2"
karpenter_capacity_types    = ["spot", "on-demand"]
karpenter_node_cpu_limit    = "1000"
karpenter_node_memory_limit = "1000Gi"

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Produccion"
  Proyecto         = "AGAT"
  Descripcion      = "Workload - EKS cluster y addons - Prod"
  Nombre           = "agat-prod-workload"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "AGAT_Infraestructura_IaC"
}
