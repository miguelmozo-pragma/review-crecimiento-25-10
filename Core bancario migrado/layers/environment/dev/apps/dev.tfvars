###############################################
# Core_Bancario - Apps - Dev
# Namespaces + microservicios (ECR, IRSA, k8s, pipeline)
# pods dev: 1 réplica, 512Mi / 256m
###############################################

project     = "cb"
environment = "dev"
region      = "us-west-2"
profile     = ""

cluster_name = "core"

###############################################
# Namespaces
###############################################
namespaces = ["frontend", "public-access", "administrative-access"]

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
      "alb.ingress.kubernetes.io/scheme"                      = "internal"
      "alb.ingress.kubernetes.io/target-type"                 = "ip"
      "alb.ingress.kubernetes.io/group.name"                  = "cb-dev-public"
      "alb.ingress.kubernetes.io/load-balancer-name"          = "cb-dev-alb-public"
      "alb.ingress.kubernetes.io/security-group-prefix-lists" = "pl-82a045eb"
    }
    ingress_path        = "/"
    create_pipeline     = false
    pipeline_repository = "bgsas/cb-frontend"
  }

  estado-cuentas = {
    namespace          = "public-access"
    container_port     = 8080
    service_port       = 80
    replicas           = 1
    resources_requests = { cpu = "128m", memory = "256Mi" }
    resources_limits   = { cpu = "256m", memory = "512Mi" }
    create_ingress     = true
    ingress_class_name = "alb"
    ingress_annotations = {
      "alb.ingress.kubernetes.io/scheme"                      = "internal"
      "alb.ingress.kubernetes.io/target-type"                 = "ip"
      "alb.ingress.kubernetes.io/group.name"                  = "cb-dev-public"
      "alb.ingress.kubernetes.io/load-balancer-name"          = "cb-dev-alb-public"
      "alb.ingress.kubernetes.io/security-group-prefix-lists" = "pl-82a045eb"
    }
    ingress_path        = "/estado-cuentas"
    create_pipeline     = false
    pipeline_repository = "bgsas/cb-estado-cuentas"
  }

  creditos = {
    namespace          = "administrative-access"
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
      "alb.ingress.kubernetes.io/group.name"         = "cb-dev-admin"
      "alb.ingress.kubernetes.io/load-balancer-name" = "cb-dev-alb-admin"
    }
    ingress_path        = "/creditos"
    create_pipeline     = false
    pipeline_repository = "bgsas/cb-creditos"
  }

  recaudo = {
    namespace          = "administrative-access"
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
      "alb.ingress.kubernetes.io/group.name"         = "cb-dev-admin"
      "alb.ingress.kubernetes.io/load-balancer-name" = "cb-dev-alb-admin"
    }
    ingress_path        = "/recaudo"
    create_pipeline     = false
    pipeline_repository = "bgsas/cb-recaudo"
  }

  inversiones = {
    namespace          = "administrative-access"
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
      "alb.ingress.kubernetes.io/group.name"         = "cb-dev-admin"
      "alb.ingress.kubernetes.io/load-balancer-name" = "cb-dev-alb-admin"
    }
    ingress_path        = "/inversiones"
    create_pipeline     = false
    pipeline_repository = "bgsas/cb-inversiones"
  }

  administrativo = {
    namespace          = "administrative-access"
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
      "alb.ingress.kubernetes.io/group.name"         = "cb-dev-admin"
      "alb.ingress.kubernetes.io/load-balancer-name" = "cb-dev-alb-admin"
    }
    ingress_path        = "/administrativo"
    create_pipeline     = false
    pipeline_repository = "bgsas/cb-administrativo"
  }
}

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Desarrollo"
  Proyecto         = "Core_Bancario"
  Descripcion      = "Apps - Microservicios EKS - Dev"
  Nombre           = "cb-dev-apps"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
