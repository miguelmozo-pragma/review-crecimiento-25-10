output "distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name (e.g. dxxxx.cloudfront.net)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Route53 hosted zone ID of the CloudFront distribution (for alias records)"
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "vpc_origin_id" {
  description = "ID of the CloudFront VPC origin pointing to the internal ALB"
  value       = aws_cloudfront_vpc_origin.this.id
}

output "vpc_origin_arn" {
  description = "ARN of the CloudFront VPC origin"
  value       = aws_cloudfront_vpc_origin.this.arn
}
