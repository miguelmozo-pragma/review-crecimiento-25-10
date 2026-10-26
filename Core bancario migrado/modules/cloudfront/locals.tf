locals {
  # Convención de nomenclatura Core Bancario: cb-{environment}-{componente}-{funcionalidad}
  # El componente (cf) se incluye como literal, no se pasa como variable.
  base_name = "cb-${var.environment}"

  distribution_name = "${local.base_name}-cf-${var.distribution_name}"
  vpc_origin_name   = "${local.base_name}-cf-${var.distribution_name}-vpc-origin"

  origin_id = "alb-vpc-origin-${var.distribution_name}"

  # Usa certificado custom si se pasó un ACM ARN; de lo contrario el default de CloudFront
  use_custom_certificate = var.acm_certificate_arn != null
}
