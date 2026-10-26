locals {
  # Convención de nomenclatura Core Bancario: cb-{environment}-{componente}-{funcionalidad}
  # El componente (eks) se incluye como literal, no se pasa como variable.
  base_name = "cb-${var.environment}"

  # Nombre del cluster EKS
  cluster_name = "${local.base_name}-eks-${var.cluster_name}"

  # Nombres de roles IRSA
  lb_controller_role_name = "${local.base_name}-eks-${var.cluster_name}-lb-controller"
  ebs_csi_role_name       = "${local.base_name}-eks-${var.cluster_name}-ebs-csi"

  # Prefijo para node groups: cb-{env}-eks-{funcionalidad}-ng-{key}
  node_group_names = {
    for k, v in var.node_groups : k => "${local.base_name}-eks-${var.cluster_name}-ng-${k}"
  }

  # Subnets que usa Karpenter (por defecto las mismas del cluster)
  karpenter_subnet_ids = length(var.karpenter_subnet_ids) > 0 ? var.karpenter_subnet_ids : var.subnet_ids

  # Tags base del módulo (merge con additional_tags en cada recurso)
  cluster_tags = merge(
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    },
    var.additional_tags
  )
}
