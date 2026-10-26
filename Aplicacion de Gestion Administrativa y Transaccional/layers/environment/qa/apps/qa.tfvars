###############################################
# AGAT - Apps - QA
# Namespaces + microservicios (frontend, backend)
# Exposición interna vía ALB (Ingress internal).
###############################################

project     = "agat"
environment = "qa"
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
pipeline_artifact_bucket_name = "bgsas-pipeline-artifacts-qa"

###############################################
# Microservicios
#   - frontend: aplicación web (interna, ALB)
#   - backend: microservicios de lógica/negocio (interno, ALB)
# pods prod: 3 réplicas, 1024Mi / 512m
###############################################
microservices = {
  frontend = {
    namespace          = "frontend"
    container_port     = 8080
    service_port       = 80
    replicas           = 3
    resources_requests = { cpu = "256m", memory = "512Mi" }
    resources_limits   = { cpu = "512m", memory = "1024Mi" }
    create_ingress     = true
    ingress_class_name = "alb"
    ingress_annotations = {
      "alb.ingress.kubernetes.io/scheme"             = "internal"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/group.name"         = "agat-qa-internal"
      "alb.ingress.kubernetes.io/load-balancer-name" = "agat-qa-alb-internal"
    }
    ingress_path        = "/"
    create_pipeline     = true
    pipeline_repository = "bgsas/agat-frontend"
  }

  backend = {
    namespace          = "backend"
    container_port     = 8080
    service_port       = 80
    replicas           = 3
    resources_requests = { cpu = "256m", memory = "512Mi" }
    resources_limits   = { cpu = "512m", memory = "1024Mi" }
    create_ingress     = true
    ingress_class_name = "alb"
    ingress_annotations = {
      "alb.ingress.kubernetes.io/scheme"             = "internal"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/group.name"         = "agat-qa-internal"
      "alb.ingress.kubernetes.io/load-balancer-name" = "agat-qa-alb-internal"
    }
    ingress_path        = "/api"
    create_pipeline     = true
    pipeline_repository = "bgsas/agat-backend"
  }
}

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Calidad"
  Proyecto         = "AGAT"
  Descripcion      = "Apps - Microservicios EKS - QA"
  Nombre           = "agat-qa-apps"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "AGAT_Infraestructura_IaC"
}
