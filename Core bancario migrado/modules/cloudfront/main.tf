###########################################
# CloudFront + VPC Origin apuntando a un ALB interno
###########################################

# ==========================================================================
# VPC Origin: conexión privada de CloudFront hacia el ALB interno.
# El ALB NO es internet-facing; solo CloudFront puede alcanzarlo.
# ==========================================================================
resource "aws_cloudfront_vpc_origin" "this" {
  provider = aws.project

  vpc_origin_endpoint_config {
    name                   = local.vpc_origin_name
    arn                    = var.alb_arn
    http_port              = var.vpc_origin_http_port
    https_port             = var.vpc_origin_https_port
    origin_protocol_policy = var.vpc_origin_protocol_policy

    origin_ssl_protocols {
      items    = var.vpc_origin_ssl_protocols
      quantity = length(var.vpc_origin_ssl_protocols)
    }
  }

  tags = merge(
    { Name = local.vpc_origin_name },
    var.additional_tags
  )
}

# ==========================================================================
# CloudFront Distribution
# ==========================================================================
resource "aws_cloudfront_distribution" "this" {
  provider = aws.project
  # checkov:skip=CKV2_AWS_32: La política de headers de respuesta se gestiona fuera de este módulo base
  # checkov:skip=CKV_AWS_68: WAF es opcional vía var.web_acl_id segun ambiente
  # checkov:skip=CKV_AWS_86: Access logging se habilita a nivel de layer cuando exista el bucket de logs

  enabled             = var.enabled
  is_ipv6_enabled     = true
  comment             = local.distribution_name
  price_class         = var.price_class
  aliases             = var.aliases
  default_root_object = var.default_root_object != "" ? var.default_root_object : null
  web_acl_id          = var.web_acl_id

  # ---- Origin: ALB interno vía VPC Origin ----
  origin {
    domain_name = var.alb_domain_name
    origin_id   = local.origin_id

    vpc_origin_config {
      vpc_origin_id            = aws_cloudfront_vpc_origin.this.id
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }
  }

  # ---- Comportamiento de caché por defecto (app dinámica) ----
  default_cache_behavior {
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = var.allowed_methods
    cached_methods         = var.cached_methods
    compress               = true

    cache_policy_id          = var.cache_policy_id
    origin_request_policy_id = var.origin_request_policy_id
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = local.use_custom_certificate ? null : true
    acm_certificate_arn            = local.use_custom_certificate ? var.acm_certificate_arn : null
    ssl_support_method             = local.use_custom_certificate ? "sni-only" : null
    minimum_protocol_version       = local.use_custom_certificate ? var.minimum_protocol_version : null
  }

  tags = merge(
    { Name = local.distribution_name },
    var.additional_tags
  )
}
