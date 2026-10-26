###############################################
# Outputs
###############################################

output "cluster_name" {
  description = "Nombre del cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint del API server del cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "ARN del cluster EKS"
  value       = module.eks.cluster_arn
}

output "cluster_security_group_id" {
  description = "Security group del control plane de EKS"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group de los node groups de EKS"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN del OIDC provider para IRSA"
  value       = module.eks.oidc_provider_arn
}

output "lb_controller_role_arn" {
  description = "ARN del rol IRSA del AWS Load Balancer Controller"
  value       = module.eks.lb_controller_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "Nombre del IAM role de los nodos de Karpenter"
  value       = module.eks.karpenter_node_iam_role_name
}
