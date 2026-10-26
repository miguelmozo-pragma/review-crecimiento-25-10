###########################################
########## Common variables ###############
###########################################

variable "project" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment where resources will be deployed"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Must be dev, qa, or prod."
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources will be deployed"
}

variable "distribution_name" {
  type        = string
  description = "Functional name for the distribution ({funcionalidad} segment), e.g. 'portal'. Final name: cb-{env}-cf-{distribution_name}."
}

###########################################
########## VPC Origin (ALB) ###############
###########################################

variable "alb_arn" {
  type        = string
  description = "ARN of the internal ALB used as CloudFront VPC origin."
}

variable "alb_domain_name" {
  type        = string
  description = "DNS name of the internal ALB (used as the origin domain name)."
}

variable "vpc_origin_http_port" {
  type        = number
  description = "HTTP port CloudFront uses to reach the ALB VPC origin."
  default     = 80
}

variable "vpc_origin_https_port" {
  type        = number
  description = "HTTPS port CloudFront uses to reach the ALB VPC origin."
  default     = 443
}

variable "vpc_origin_protocol_policy" {
  type        = string
  description = "Origin protocol policy CloudFront uses to connect to the ALB (http-only, https-only, match-viewer)."
  default     = "https-only"
  validation {
    condition     = contains(["http-only", "https-only", "match-viewer"], var.vpc_origin_protocol_policy)
    error_message = "Must be http-only, https-only, or match-viewer."
  }
}

variable "vpc_origin_ssl_protocols" {
  type        = list(string)
  description = "SSL/TLS protocols CloudFront uses when connecting to the origin over HTTPS."
  default     = ["TLSv1.2"]
}

###########################################
########## Distribution settings ##########
###########################################

variable "enabled" {
  type        = bool
  description = "Whether the distribution is enabled."
  default     = true
}

variable "price_class" {
  type        = string
  description = "CloudFront price class."
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "aliases" {
  type        = list(string)
  description = "Custom domain names (CNAMEs) for the distribution. Requires acm_certificate_arn."
  default     = []
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN (MUST be in us-east-1) for custom domains. When null, the CloudFront default certificate is used."
  default     = null
}

variable "minimum_protocol_version" {
  type        = string
  description = "Minimum TLS version for viewer connections (when using a custom certificate)."
  default     = "TLSv1.2_2021"
}

variable "default_root_object" {
  type        = string
  description = "Object CloudFront returns when the root URL is requested."
  default     = ""
}

###########################################
########## Cache behavior #################
###########################################

variable "allowed_methods" {
  type        = list(string)
  description = "HTTP methods CloudFront processes and forwards to the origin."
  default     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
}

variable "cached_methods" {
  type        = list(string)
  description = "HTTP methods for which CloudFront caches responses."
  default     = ["GET", "HEAD"]
}

variable "cache_policy_id" {
  type        = string
  description = "Managed cache policy ID. Defaults to the AWS managed 'CachingDisabled' policy (dynamic app behind ALB)."
  default     = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
}

variable "origin_request_policy_id" {
  type        = string
  description = "Managed origin request policy ID. Defaults to 'AllViewer' so headers/query/cookies reach the ALB."
  default     = "216adef6-5c7f-47e4-b989-5492eafa07d3" # Managed-AllViewer
}

variable "geo_restriction_type" {
  type        = string
  description = "Geo restriction type (none, whitelist, blacklist)."
  default     = "none"
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "Must be none, whitelist, or blacklist."
  }
}

variable "geo_restriction_locations" {
  type        = list(string)
  description = "ISO country codes for geo restriction (when type is whitelist or blacklist)."
  default     = []
}

###########################################
########## WAF ############################
###########################################

variable "web_acl_id" {
  type        = string
  description = "ARN of the WAFv2 Web ACL to associate (must be CLOUDFRONT scope, us-east-1). Null to skip."
  default     = null
}

###########################################
########## Additional Tags ################
###########################################

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources created by this module"
  default     = {}
}
