###############################################
# Core_Bancario - Apps - QA
# Namespaces + microservicios (ECR, IRSA, k8s, pipeline)
###############################################

project     = "cb"
environment = "qa"
region      = "us-west-2"
profile     = ""

cluster_name = "core"

###############################################
# Namespaces
###############################################
namespaces = ["frontend", "public-access", "administrative-access"]

###############################################
# Pipeline (compartido)
# NOTA: pipeline_artifact_bucket_name debe apuntar a un bucket S3 existente.
# Mientras no exista, los microservicios usan create_pipeline = false.
###############################################
codestar_connection_arn       = "arn:aws:codeconnections:us-west-2:014498650162:connection/2a15ba8f-ad1f-4749-8491-7bc90b3d0137"
pipeline_artifact_bucket_name = "bgsas-pipeline-artifacts-qa"

###############################################
# Microservicios
# Según product.md:
#   - frontend y estado-cuentas: acceso público (ingress ALB)
#   - creditos/recaudo/inversiones/administrativo: acceso administrativo
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
    # ALB interno compartido (grupo cb-qa-public): solo accesible desde CloudFront vía VPC Origin.
    # El SG del ALB permite ingreso únicamente desde el managed prefix list de CloudFront.
    ingress_annotations = {
      "alb.ingress.kubernetes.io/scheme"                      = "internal"
      "alb.ingress.kubernetes.io/target-type"                 = "ip"
      "alb.ingress.kubernetes.io/group.name"                  = "cb-qa-public"
      "alb.ingress.kubernetes.io/load-balancer-name"          = "cb-qa-alb-public"
      "alb.ingress.kubernetes.io/security-group-prefix-lists" = "pl-82a045eb"
    }
    ingress_path        = "/"
    create_pipeline     = true
    pipeline_repository = "bgsas/cb-frontend"
  }

  estado-cuentas = {
    namespace          = "public-access"
    container_port     = 8080
    service_port       = 80
    replicas           = 3
    resources_requests = { cpu = "256m", memory = "512Mi" }
    resources_limits   = { cpu = "512m", memory = "1024Mi" }
    create_ingress     = true
    ingress_class_name = "alb"
    # ALB interno compartido (grupo cb-qa-public): solo accesible desde CloudFront vía VPC Origin.
    # El SG del ALB permite ingreso únicamente desde el managed prefix list de CloudFront.
    ingress_annotations = {
      "alb.ingress.kubernetes.io/scheme"                      = "internal"
      "alb.ingress.kubernetes.io/target-type"                 = "ip"
      "alb.ingress.kubernetes.io/group.name"                  = "cb-qa-public"
      "alb.ingress.kubernetes.io/load-balancer-name"          = "cb-qa-alb-public"
      "alb.ingress.kubernetes.io/security-group-prefix-lists" = "pl-82a045eb"
    }
    ingress_path        = "/estado-cuentas"
    create_pipeline     = true
    pipeline_repository = "bgsas/cb-estado-cuentas"
  }

  creditos = {
    namespace          = "administrative-access"
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
      "alb.ingress.kubernetes.io/group.name"         = "cb-qa-admin"
      "alb.ingress.kubernetes.io/load-balancer-name" = "cb-qa-alb-admin"
    }
    ingress_path        = "/creditos"
    create_pipeline     = true
    pipeline_repository = "bgsas/cb-creditos"
  }

  recaudo = {
    namespace          = "administrative-access"
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
      "alb.ingress.kubernetes.io/group.name"         = "cb-qa-admin"
      "alb.ingress.kubernetes.io/load-balancer-name" = "cb-qa-alb-admin"
    }
    ingress_path        = "/recaudo"
    create_pipeline     = true
    pipeline_repository = "bgsas/cb-recaudo"
  }

  inversiones = {
    namespace          = "administrative-access"
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
      "alb.ingress.kubernetes.io/group.name"         = "cb-qa-admin"
      "alb.ingress.kubernetes.io/load-balancer-name" = "cb-qa-alb-admin"
    }
    ingress_path        = "/inversiones"
    create_pipeline     = true
    pipeline_repository = "bgsas/cb-inversiones"
  }

  administrativo = {
    namespace          = "administrative-access"
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
      "alb.ingress.kubernetes.io/group.name"         = "cb-qa-admin"
      "alb.ingress.kubernetes.io/load-balancer-name" = "cb-qa-alb-admin"
    }
    ingress_path        = "/administrativo"
    create_pipeline     = true
    pipeline_repository = "bgsas/cb-administrativo"
  }
}

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Calidad"
  Proyecto         = "Core_Bancario"
  Descripcion      = "Apps - Microservicios EKS - QA"
  Nombre           = "cb-qa-apps"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
