###############################################
# Gobierno: CloudFront
# Ambiente: ALL
#
# Recursos:
#   - CloudFront VPC Origin -> ALB interno (cb-prod-alb-public)
#   - CloudFront Distribution
#   - SSM Parameters con outputs del layer
###############################################

# ==========================================================================
# 1. CloudFront + VPC Origin apuntando al ALB interno del portal
# ==========================================================================
module "cloudfront" {
  source = "../../modules/cloudfront"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  distribution_name = var.distribution_name

  # ALB interno (resuelto por data source, camino 2)
  alb_arn         = data.aws_lb.public.arn
  alb_domain_name = data.aws_lb.public.dns_name

  # Dominio / certificado
  aliases             = var.aliases
  acm_certificate_arn = var.acm_certificate_arn

  # Distribución
  price_class = var.price_class
  web_acl_id  = var.web_acl_id

  # Tags
  additional_tags = var.common_tags
}

# ==========================================================================
# 2. Publicación de outputs en SSM Parameter Store
#    Patrón: /cb/{environment}/cloudfront/{recurso}
# ==========================================================================
resource "aws_ssm_parameter" "distribution_id" {
  provider = aws.project
  name     = "/cb/${var.environment}/cloudfront/distribution-id"
  type     = "String"
  value    = module.cloudfront.distribution_id
  tags     = merge({ Name = "/cb/${var.environment}/cloudfront/distribution-id" }, var.common_tags)
}

resource "aws_ssm_parameter" "distribution_domain_name" {
  provider = aws.project
  name     = "/cb/${var.environment}/cloudfront/distribution-domain-name"
  type     = "String"
  value    = module.cloudfront.distribution_domain_name
  tags     = merge({ Name = "/cb/${var.environment}/cloudfront/distribution-domain-name" }, var.common_tags)
}
