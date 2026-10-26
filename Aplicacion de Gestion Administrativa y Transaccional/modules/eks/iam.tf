###########################################
########### IRSA Roles ####################
###########################################

# IRSA role for the AWS EBS CSI driver addon
module "ebs_csi_role" {
  count   = var.ebs_csi_driver ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = local.ebs_csi_role_name
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.additional_tags
}

# IRSA role for the AWS Load Balancer Controller
# Uses the upstream managed policy (attach_load_balancer_controller_policy)
# so we don't maintain the large IAM JSON by hand.
module "lb_controller_role" {
  count   = var.enable_lb_controller ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = local.lb_controller_role_name
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.additional_tags
}
