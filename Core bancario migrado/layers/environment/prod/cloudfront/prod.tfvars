###############################################
# Core_Bancario - CloudFront - Prod
# CloudFront + VPC Origin -> ALB interno del portal (cb-prod-alb-public)
###############################################

project     = "cb"
environment = "prod"
region      = "us-west-2"
profile     = ""

###############################################
# CloudFront / ALB
###############################################
distribution_name = "portal"
alb_name          = "cb-prod-alb-public"

# Certificado y dominios custom (opcional). El ACM debe estar en us-east-1.
acm_certificate_arn = null
aliases             = []

price_class = "PriceClass_100"
web_acl_id  = null

###############################################
# Tags corporativos
###############################################
common_tags = {
  Ambiente         = "Produccion"
  Proyecto         = "Core_Bancario"
  Descripcion      = "CloudFront - VPC Origin al ALB interno del portal - Prod"
  Nombre           = "cb-prod-cloudfront"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "Core_Bancario_Infraestructura_IaC"
}
