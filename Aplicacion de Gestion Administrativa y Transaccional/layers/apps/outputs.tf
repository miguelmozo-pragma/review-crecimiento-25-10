###############################################
# Outputs
###############################################

output "namespaces" {
  description = "Namespaces de Kubernetes creados"
  value       = [for ns in kubernetes_namespace_v1.this : ns.metadata[0].name]
}

output "ecr_repository_urls" {
  description = "URLs de los repositorios ECR por microservicio"
  value       = { for k, m in module.microservice : k => m.ecr_repository_url }
}

output "irsa_role_arns" {
  description = "ARNs de los roles IRSA por microservicio"
  value       = { for k, m in module.microservice : k => m.irsa_role_arn }
}

output "service_names" {
  description = "Nombres de los Kubernetes Service por microservicio"
  value       = { for k, m in module.microservice : k => m.service_name }
}

output "pipeline_names" {
  description = "Nombres de los pipelines por microservicio (null si no se creó)"
  value       = { for k, m in module.microservice : k => m.pipeline_name }
}
