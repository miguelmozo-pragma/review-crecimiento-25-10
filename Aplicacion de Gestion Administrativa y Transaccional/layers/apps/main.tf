###############################################
# Gobierno: Apps
# Ambiente: ALL
#
# Recursos:
#   - Namespaces de Kubernetes (N)
#   - Microservicios (ECR + IRSA + SA + Deployment/Service/Ingress + pipeline)
###############################################

# ==========================================================================
# 1. Namespaces de Kubernetes
# ==========================================================================
resource "kubernetes_namespace_v1" "this" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.value
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = var.environment
    }
  }
}

# ==========================================================================
# 2. Microservicios
# ==========================================================================
module "microservice" {
  source   = "../../modules/microservice"
  for_each = var.microservices

  providers = {
    aws.project = aws.project
    kubernetes  = kubernetes
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Identidad del servicio
  service_name = each.key
  namespace    = each.value.namespace

  # IRSA
  oidc_provider_arn = local.oidc_provider_arn
  oidc_provider_url = local.oidc_provider_url
  policy_statements = each.value.policy_statements

  # ECR
  ecr_max_image_count  = each.value.ecr_max_image_count
  image_tag_mutability = each.value.image_tag_mutability

  # Deployment
  image              = each.value.image
  replicas           = each.value.replicas
  container_port     = each.value.container_port
  resources_requests = each.value.resources_requests
  resources_limits   = each.value.resources_limits
  env                = each.value.env

  # Service
  service_port = each.value.service_port

  # Ingress
  create_ingress      = each.value.create_ingress
  ingress_class_name  = each.value.ingress_class_name
  ingress_annotations = each.value.ingress_annotations
  ingress_host        = each.value.ingress_host
  ingress_path        = each.value.ingress_path

  # Pipeline CI/CD
  create_pipeline               = each.value.create_pipeline
  codestar_connection_arn       = var.codestar_connection_arn
  pipeline_repository           = each.value.pipeline_repository
  pipeline_branch               = each.value.pipeline_branch
  pipeline_buildspec            = each.value.pipeline_buildspec
  pipeline_artifact_bucket_name = var.pipeline_artifact_bucket_name
  cluster_name                  = local.eks_cluster_name

  # Tags
  additional_tags = var.common_tags

  depends_on = [kubernetes_namespace_v1.this]
}
