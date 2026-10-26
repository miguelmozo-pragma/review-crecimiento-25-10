output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS managed node groups"
  value       = module.eks.node_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = module.eks.cluster_version
}

output "lb_controller_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller (IRSA)"
  value       = var.enable_lb_controller ? module.lb_controller_role[0].iam_role_arn : null
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN used by the EBS CSI driver (IRSA)"
  value       = var.ebs_csi_driver ? module.ebs_csi_role[0].iam_role_arn : null
}

output "karpenter_node_iam_role_name" {
  description = "IAM role name assumed by Karpenter-provisioned nodes"
  value       = var.enable_karpenter ? module.karpenter[0].node_iam_role_name : null
}

output "karpenter_queue_name" {
  description = "Karpenter interruption SQS queue name"
  value       = var.enable_karpenter ? module.karpenter[0].queue_name : null
}
