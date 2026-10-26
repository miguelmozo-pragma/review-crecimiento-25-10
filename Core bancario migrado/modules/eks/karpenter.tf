###########################################
############## Karpenter ###################
###########################################

# Karpenter controller IAM + interruption queue (upstream submodule)
module "karpenter" {
  count   = var.enable_karpenter ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  providers = {
    aws = aws.project
  }

  cluster_name = module.eks.cluster_name

  enable_irsa                     = true
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["kube-system:karpenter"]

  # Crea el node IAM role que usará EC2NodeClass
  create_node_iam_role = true
  node_iam_role_name   = "${local.cluster_name}-karpenter-node"

  tags = var.additional_tags
}

# Karpenter Helm release
resource "helm_release" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_chart_version
  namespace  = "kube-system"

  set = [
    {
      name  = "settings.clusterName"
      value = module.eks.cluster_name
    },
    {
      name  = "settings.clusterEndpoint"
      value = module.eks.cluster_endpoint
    },
    {
      name  = "settings.interruptionQueue"
      value = module.karpenter[0].queue_name
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.karpenter[0].iam_role_arn
    },
    {
      name  = "controller.resources.requests.cpu"
      value = "200m"
    },
    {
      name  = "controller.resources.requests.memory"
      value = "128Mi"
    },
    {
      name  = "controller.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "controller.resources.limits.memory"
      value = "256Mi"
    },
    {
      name  = "replicas"
      value = "1"
    }
  ]

  depends_on = [
    module.karpenter,
    helm_release.lb_controller
  ]
}

# EC2NodeClass: define cómo Karpenter lanza nodos (AMI, role, subnets, SG)
resource "kubectl_manifest" "karpenter_node_class" {
  count = var.enable_karpenter ? 1 : 0

  yaml_body = templatefile("${path.module}/k8s_resources/ec2nodeclass.yaml", {
    cluster_name = module.eks.cluster_name
    node_role    = module.karpenter[0].node_iam_role_name
    subnet_ids   = local.karpenter_subnet_ids
  })

  depends_on = [helm_release.karpenter]
}

# NodePool: define requisitos y límites de los nodos que Karpenter aprovisiona
resource "kubectl_manifest" "karpenter_node_pool" {
  count = var.enable_karpenter ? 1 : 0

  yaml_body = templatefile("${path.module}/k8s_resources/nodepool.yaml", {
    capacity_types = join(", ", [for c in var.karpenter_capacity_types : "\"${c}\""])
    cpu_limit      = var.karpenter_node_cpu_limit
    memory_limit   = var.karpenter_node_memory_limit
  })

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_node_class
  ]
}
