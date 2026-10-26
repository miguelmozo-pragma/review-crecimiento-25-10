###########################################
########### EKS Cluster ###################
###########################################

# Latest EKS optimized AMI release version for the chosen cluster version
data "aws_ssm_parameter" "eks_ami_release_version" {
  provider = aws.project
  name     = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/x86_64/standard/recommended/release_version"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  providers = {
    aws = aws.project
  }

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  enable_irsa                              = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_addons = merge(
    {
      coredns = {
        most_recent = true
      }
      kube-proxy = {
        most_recent = true
      }
      vpc-cni = {
        most_recent    = true
        before_compute = true
      }
    },
    var.ebs_csi_driver ? {
      aws-ebs-csi-driver = {
        most_recent              = true
        service_account_role_arn = module.ebs_csi_role[0].iam_role_arn
      }
    } : {}
  )

  eks_managed_node_groups = {
    for ng_key, ng in var.node_groups : ng_key => {
      name                     = local.node_group_names[ng_key]
      use_name_prefix          = false
      instance_types           = ng.instance_types
      capacity_type            = ng.capacity_type
      min_size                 = ng.min_size
      max_size                 = ng.max_size
      desired_size             = ng.desired_size
      disk_size                = ng.disk_size
      force_update_version     = true
      release_version          = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value)
      iam_role_name            = "${local.node_group_names[ng_key]}-role"
      iam_role_use_name_prefix = false
      labels                   = ng.labels
      taints                   = ng.taints

      update_config = {
        max_unavailable_percentage = 50
      }
    }
  }

  tags = local.cluster_tags
}
