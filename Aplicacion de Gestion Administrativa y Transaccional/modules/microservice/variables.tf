###########################################
# Common
###########################################

variable "project" {
  type        = string
  description = "Project code (workload). Always 'cb' for Core Bancario."
}

variable "environment" {
  type        = string
  description = "Environment where resources will be deployed."
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Must be dev, qa, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources will be deployed."
}

###########################################
# Service identity
###########################################

variable "service_name" {
  type        = string
  description = "Microservice name ({funcionalidad} segment), e.g. 'frontend'. Lowercase and hyphens only."
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_name))
    error_message = "service_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where the microservice resources are deployed."
}

variable "service_account_name" {
  type        = string
  description = "Kubernetes ServiceAccount name. Defaults to service_name when empty."
  default     = ""
}

###########################################
# ECR
###########################################

variable "image_tag_mutability" {
  type        = string
  description = "ECR image tag mutability setting."
  default     = "IMMUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "ecr_max_image_count" {
  type        = number
  description = "Number of most recent images to keep in the ECR repository."
  default     = 10
  validation {
    condition     = var.ecr_max_image_count >= 1
    error_message = "ecr_max_image_count must be >= 1."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "Optional KMS key ARN for ECR encryption. When null, AES256 is used."
  default     = null
}

###########################################
# IRSA (IAM Role for Service Account)
###########################################

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster OIDC provider for IRSA trust."
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the EKS cluster OIDC provider without the https:// prefix."
}

variable "policy_statements" {
  type = list(object({
    sid       = string
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  description = "Inline IAM policy statements attached to the IRSA role. When empty no inline policy is created."
  default     = []
}

###########################################
# Deployment
###########################################

variable "image" {
  type        = string
  description = "Container image. Defaults to '<ecr_repo_url>:latest' when empty."
  default     = ""
}

variable "replicas" {
  type        = number
  description = "Number of pod replicas for the deployment."
  default     = 1
  validation {
    condition     = var.replicas >= 1
    error_message = "replicas must be >= 1."
  }
}

variable "container_port" {
  type        = number
  description = "Container port exposed by the microservice."
  default     = 8080
}

variable "resources_requests" {
  type        = map(string)
  description = "Resource requests (cpu/memory) for the container."
  default = {
    cpu    = "256m"
    memory = "256Mi"
  }
}

variable "resources_limits" {
  type        = map(string)
  description = "Resource limits (cpu/memory) for the container."
  default = {
    cpu    = "512m"
    memory = "512Mi"
  }
}

variable "env" {
  type        = map(string)
  description = "Environment variables injected into the container."
  default     = {}
}

variable "wait_for_rollout" {
  type        = bool
  description = "Whether Terraform waits for the deployment rollout to complete. Set to false for infra-first deployments where the container image is pushed later by the pipeline."
  default     = false
}

###########################################
# Service
###########################################

variable "service_type" {
  type        = string
  description = "Kubernetes Service type."
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "service_type must be ClusterIP, NodePort, or LoadBalancer."
  }
}

variable "service_port" {
  type        = number
  description = "Port exposed by the Kubernetes Service."
  default     = 80
}

###########################################
# Ingress
###########################################

variable "create_ingress" {
  type        = bool
  description = "Whether to create a Kubernetes Ingress for the microservice."
  default     = false
}

variable "ingress_class_name" {
  type        = string
  description = "Ingress class name."
  default     = "alb"
}

variable "ingress_annotations" {
  type        = map(string)
  description = "Annotations applied to the Ingress resource."
  default     = {}
}

variable "ingress_host" {
  type        = string
  description = "Host for the Ingress rule. Empty means no host match."
  default     = ""
}

variable "ingress_path" {
  type        = string
  description = "Path for the Ingress rule."
  default     = "/"
}

variable "ingress_path_type" {
  type        = string
  description = "Path type for the Ingress rule."
  default     = "Prefix"
  validation {
    condition     = contains(["Prefix", "Exact", "ImplementationSpecific"], var.ingress_path_type)
    error_message = "ingress_path_type must be Prefix, Exact, or ImplementationSpecific."
  }
}

###########################################
# Pipeline (CI/CD for application code)
###########################################

variable "create_pipeline" {
  type        = bool
  description = "Whether to create the CodePipeline + CodeBuild stack for the application code."
  default     = false
}

variable "codestar_connection_arn" {
  type        = string
  description = "CodeStar connection ARN used by the pipeline source stage."
  default     = null
}

variable "pipeline_repository" {
  type        = string
  description = "Source repository in 'owner/repo' format."
  default     = ""
}

variable "pipeline_branch" {
  type        = string
  description = "Source branch for the pipeline."
  default     = "main"
}

variable "pipeline_buildspec" {
  type        = string
  description = "Buildspec file used by CodeBuild."
  default     = "buildspec.yml"
}

variable "pipeline_compute_type" {
  type        = string
  description = "CodeBuild compute type."
  default     = "BUILD_GENERAL1_SMALL"
  validation {
    condition     = contains(["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE"], var.pipeline_compute_type)
    error_message = "pipeline_compute_type must be BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, or BUILD_GENERAL1_LARGE."
  }
}

variable "pipeline_build_image" {
  type        = string
  description = "CodeBuild container image."
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

variable "pipeline_artifact_bucket_name" {
  type        = string
  description = "S3 bucket name used to store pipeline artifacts."
  default     = null
}

variable "pipeline_environment_variables" {
  type = list(object({
    name  = string
    value = string
    type  = string
  }))
  description = "Additional environment variables for the CodeBuild project."
  default     = []
}

variable "grant_eks_access" {
  type        = bool
  description = "Whether to grant the CodeBuild role EKS edit access scoped to the namespace via an access entry."
  default     = true
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name the CodeBuild role deploys to."
}

###########################################
# Tags
###########################################

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags merged into every AWS resource."
  default     = {}
}
