###########################################
# Naming convention
# Pattern: agat-{environment}-{componente}-{funcionalidad}
# The {componente} segment is a literal per resource type
# (ecr, role, policy, pipeline) and is never passed as a variable.
###########################################

locals {
  base_name = "agat-${var.environment}"

  # Resource names (literal component segments)
  ecr_repo_name    = "${local.base_name}-ecr-${var.service_name}"
  irsa_role_name   = "${local.base_name}-role-${var.service_name}"
  irsa_policy_name = "${local.base_name}-policy-${var.service_name}"

  # Pipeline naming (agat-{env}-pipeline-{funcionalidad})
  pipeline_name       = "agat-${var.environment}-pipeline-${var.service_name}"
  codebuild_name      = "agat-${var.environment}-pipeline-${var.service_name}-build"
  pipeline_role_name  = "agat-${var.environment}-pipeline-${var.service_name}-pl-role"
  codebuild_role_name = "agat-${var.environment}-pipeline-${var.service_name}-cb-role"

  # Computed convenience values
  service_account_name = var.service_account_name != "" ? var.service_account_name : var.service_name
  app_label            = var.service_name
  container_image      = var.image != "" ? var.image : "${aws_ecr_repository.this.repository_url}:latest"
}
