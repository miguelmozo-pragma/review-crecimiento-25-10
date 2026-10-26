###########################################
# microservice module
# Deploys every resource for a microservice on EKS:
#   - ECR repository          (ecr.tf)
#   - IRSA IAM role           (iam.tf)
#   - Kubernetes SA/Deploy/Svc/Ingress (k8s.tf)
#   - CI/CD pipeline          (pipeline.tf)
# Shared data sources live here.
###########################################

data "aws_caller_identity" "current" {
  provider = aws.project
}
