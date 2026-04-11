variable "bucket_name" {
  description = "Globally unique name for the S3 bucket. Must be lowercase, 3-63 chars, no underscores."
  type        = string
}

variable "environment" {
  description = "Deployment environment — controls cost/features (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "index_document" {
  description = "The index document returned when S3 serves the root URL."
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "The error document returned for 4xx responses."
  type        = string
  default     = "error.html"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100=US/EU cheapest; PriceClass_All=global)"
  type        = string
  default     = "PriceClass_All"
}

variable "custom_domain" {
  description = "Custom domain name for the website (e.g., example.com). Requires ACM certificate and Route53 zone."
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain. Must be in us-east-1 for CloudFront."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID where the custom domain DNS records will be created."
  type        = string
  default     = null
}
