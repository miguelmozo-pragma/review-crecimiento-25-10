###############################################
# Outputs
###############################################

output "distribution_id" {
  description = "ID de la distribución CloudFront"
  value       = module.cloudfront.distribution_id
}

output "distribution_domain_name" {
  description = "Dominio de la distribución CloudFront (dxxxx.cloudfront.net)"
  value       = module.cloudfront.distribution_domain_name
}

output "distribution_arn" {
  description = "ARN de la distribución CloudFront"
  value       = module.cloudfront.distribution_arn
}

output "vpc_origin_id" {
  description = "ID del VPC Origin que apunta al ALB interno"
  value       = module.cloudfront.vpc_origin_id
}

output "alb_arn" {
  description = "ARN del ALB interno resuelto (origen de CloudFront)"
  value       = data.aws_lb.public.arn
}
