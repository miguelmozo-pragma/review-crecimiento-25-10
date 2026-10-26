###########################################
####### AWS Load Balancer Controller ######
###########################################

# Service account bound to the IRSA role
resource "kubernetes_service_account_v1" "lb_controller" {
  count = var.enable_lb_controller ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_controller_role[0].iam_role_arn
    }
  }

  depends_on = [module.eks]
}

# Helm release for the AWS Load Balancer Controller
resource "helm_release" "lb_controller" {
  count = var.enable_lb_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.lb_controller_chart_version != "" ? var.lb_controller_chart_version : null

  set = [
    {
      name  = "clusterName"
      value = local.cluster_name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "image.repository"
      value = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/amazon/aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "replicaCount"
      value = "1"
    }
  ]

  depends_on = [
    kubernetes_service_account_v1.lb_controller
  ]
}
