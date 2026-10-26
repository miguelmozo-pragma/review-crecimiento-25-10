###############################################
# AGAT - Workload - Dev
# Cluster EKS + addons (ALB Controller, EBS CSI, Karpenter)
###############################################

project     = "agat"
environment = "dev"
region      = "us-west-2"
profile     = ""

###############################################
# EKS
###############################################
cluster_name    = "core"
cluster_version = "1.31"

cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

###############################################
# Node groups administrados (base del sistema)
###############################################
node_groups = {
  system = {
    instance_types = ["t3.small"]
    capacity_type  = "ON_DEMAND"
    min_size       = 1
    max_size       = 2
    desired_size   = 1
    disk_size      = 20
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
karpenter_capacity_types    = ["spot"]
karpenter_node_cpu_limit    = "200"
karpenter_node_memory_limit = "200Gi"

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Desarrollo"
  Proyecto         = "AGAT"
  Descripcion      = "Workload - EKS cluster y addons - Dev"
  Nombre           = "agat-dev-workload"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "AGAT_Infraestructura_IaC"
}
