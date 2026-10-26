###########################################
# Outputs
###########################################

output "ecr_repository_url" {
  description = "URL of the ECR repository."
  value       = aws_ecr_repository.this.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.this.arn
}

output "ecr_repository_name" {
  description = "Name of the ECR repository."
  value       = aws_ecr_repository.this.name
}

output "irsa_role_arn" {
  description = "ARN of the IRSA IAM role."
  value       = aws_iam_role.irsa.arn
}

output "irsa_role_name" {
  description = "Name of the IRSA IAM role."
  value       = aws_iam_role.irsa.name
}

output "service_account_name" {
  description = "Name of the Kubernetes ServiceAccount."
  value       = kubernetes_service_account_v1.this.metadata[0].name
}

output "deployment_name" {
  description = "Name of the Kubernetes Deployment."
  value       = kubernetes_deployment_v1.this.metadata[0].name
}

output "service_name" {
  description = "Name of the Kubernetes Service."
  value       = kubernetes_service_v1.this.metadata[0].name
}

output "service_cluster_ip" {
  description = "ClusterIP assigned to the Kubernetes Service."
  value       = kubernetes_service_v1.this.spec[0].cluster_ip
}

output "ingress_hostname" {
  description = "Hostname of the Ingress load balancer (null when no ingress or not yet provisioned)."
  value       = var.create_ingress ? try(kubernetes_ingress_v1.this[0].status[0].load_balancer[0].ingress[0].hostname, null) : null
}

output "pipeline_name" {
  description = "Name of the CodePipeline (null when the pipeline is disabled)."
  value       = var.create_pipeline ? aws_codepipeline.this[0].name : null
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project (null when the pipeline is disabled)."
  value       = var.create_pipeline ? aws_codebuild_project.this[0].name : null
}
