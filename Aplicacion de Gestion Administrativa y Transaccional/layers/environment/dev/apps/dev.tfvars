###############################################
# AGAT - Apps - Dev
# Namespaces + microservicios (frontend, backend)
# Exposición interna vía ALB (Ingress internal).
# pods dev: 1 réplica, 256Mi / 128m
###############################################

project     = "agat"
environment = "dev"
region      = "us-west-2"
profile     = ""

cluster_name = "core"

###############################################
# Namespaces
###############################################
namespaces = ["frontend", "backend"]

###############################################
# Pipeline (compartido)
###############################################
codestar_connection_arn       = "arn:aws:codeconnections:us-west-2:014498650162:connection/2a15ba8f-ad1f-4749-8491-7bc90b3d0137"
pipeline_artifact_bucket_name = "bgsas-pipeline-artifacts-dev"

###############################################
# Microservicios
###############################################
microservices = {
  frontend = {
    namespace          = "frontend"
    container_port     = 8080
    service_port       = 80
    replicas           = 1
    resources_requests = { cpu = "128m", memory = "256Mi" }
    resources_limits   = { cpu = "256m", memory = "512Mi" }
    create_ingress     = true
    ingress_class_name = "alb"
    ingress_annotations = {
      "alb.ingress.kubernetes.io/scheme"             = "internal"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/group.name"         = "agat-dev-internal"
      "alb.ingress.kubernetes.io/load-balancer-name" = "agat-dev-alb-internal"
    }
    ingress_path        = "/"
    create_pipeline     = false
    pipeline_repository = "bgsas/agat-frontend"
  }

  backend = {
    namespace          = "backend"
    container_port     = 8080
    service_port       = 80
    replicas           = 1
    resources_requests = { cpu = "128m", memory = "256Mi" }
    resources_limits   = { cpu = "256m", memory = "512Mi" }
    create_ingress     = true
    ingress_class_name = "alb"
    ingress_annotations = {
      "alb.ingress.kubernetes.io/scheme"             = "internal"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/group.name"         = "agat-dev-internal"
      "alb.ingress.kubernetes.io/load-balancer-name" = "agat-dev-alb-internal"
    }
    ingress_path        = "/api"
    create_pipeline     = false
    pipeline_repository = "bgsas/agat-backend"
  }
}

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Desarrollo"
  Proyecto         = "AGAT"
  Descripcion      = "Apps - Microservicios EKS - Dev"
  Nombre           = "agat-dev-apps"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "AGAT_Infraestructura_IaC"
}
