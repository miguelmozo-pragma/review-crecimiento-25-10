###########################################
########## Common variables ###############
###########################################

variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment where resources will be deployed"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Must be dev, qa, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources will be deployed"
}

variable "cluster_name" {
  type        = string
  description = "Functional name for the EKS cluster (funcionalidad segment). Final name: agat-{env}-eks-{cluster_name}."
  default     = "core"
}

###########################################
########## EKS cluster variables ##########
###########################################

variable "cluster_version" {
  type        = string
  description = "EKS Kubernetes version"
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  type        = bool
  description = "Whether the EKS API server endpoint is publicly accessible"
  default     = false
}

variable "cluster_endpoint_private_access" {
  type        = bool
  description = "Whether the EKS API server endpoint is privately accessible from within the VPC"
  default     = true
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the cluster will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the EKS cluster and node groups (typically private subnets)"
}

variable "enable_cluster_creator_admin_permissions" {
  type        = bool
  description = "Grant the Terraform caller (creator) cluster admin access entry"
  default     = true
}

###########################################
########## Node group variables ###########
###########################################

variable "node_groups" {
  type = map(object({
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = optional(number, 20)
    labels         = optional(map(string), {})
    taints = optional(map(object({
      key    = string
      value  = optional(string)
      effect = string
    })), {})
  }))
  description = "Map of EKS managed node groups. Key is the node group name. Sizing per environment is set from the layer/tfvars."
  default = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }
}

###########################################
########## Addon variables ################
###########################################

variable "enable_lb_controller" {
  type        = bool
  description = "Deploy AWS Load Balancer Controller addon (IRSA role + Helm release)"
  default     = true
}

variable "lb_controller_chart_version" {
  type        = string
  description = "Chart version for the aws-load-balancer-controller Helm release. Empty uses the latest from the repo."
  default     = ""
}

variable "ebs_csi_driver" {
  type        = bool
  description = "Install the aws-ebs-csi-driver managed addon with a dedicated IRSA role"
  default     = true
}

###########################################
########## Karpenter variables ############
###########################################

variable "enable_karpenter" {
  type        = bool
  description = "Deploy Karpenter autoscaler (IAM, Helm release, NodePool and EC2NodeClass)"
  default     = false
}

variable "karpenter_chart_version" {
  type        = string
  description = "Chart version for the karpenter Helm release"
  default     = "1.8.2"
}

variable "karpenter_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs that Karpenter uses to launch nodes (EC2NodeClass subnetSelectorTerms). Defaults to subnet_ids when empty."
  default     = []
}

variable "karpenter_node_cpu_limit" {
  type        = string
  description = "Total CPU limit for the Karpenter NodePool"
  default     = "1000"
}

variable "karpenter_node_memory_limit" {
  type        = string
  description = "Total memory limit for the Karpenter NodePool (e.g. 1000Gi)"
  default     = "1000Gi"
}

variable "karpenter_capacity_types" {
  type        = list(string)
  description = "Capacity types Karpenter is allowed to provision (spot, on-demand)"
  default     = ["spot"]
}

###########################################
########## Additional Tags ################
###########################################

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources created by this module"
  default     = {}
}
