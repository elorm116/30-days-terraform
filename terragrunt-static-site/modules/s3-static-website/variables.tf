
variable "bucket_name" {
  description = "Globally unique name for the S3 bucket. Must be lowercase, 3-63 chars, no underscores."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase letters, numbers, and hyphens only, and cannot start or end with a hyphen."
  }
}

variable "environment" {
  description = "Deployment environment. Controls force_destroy and CloudFront price class."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "tags" {
  description = "Additional tags to merge onto all resources. ManagedBy, Environment, and Project are always set."
  type        = map(string)
  default     = {}
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
  description = "CloudFront price class controlling which edge locations serve content. PriceClass_100 = US/EU only (cheapest). PriceClass_200 adds Asia/Middle East. PriceClass_All = all edge locations."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "Price class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "default_ttl" {
  description = "Default CloudFront cache TTL in seconds. 3600 = 1 hour."
  type        = number
  default     = 3600
}

variable "max_ttl" {
  description = "Maximum CloudFront cache TTL in seconds. 86400 = 24 hours."
  type        = number
  default     = 86400
}

variable "custom_domain" {
  description = "Optional custom domain name (e.g. blog.mali.dev). Requires acm_certificate_arn to also be set."
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate in us-east-1 for the custom domain. Required if custom_domain is set. CloudFront only accepts certificates from us-east-1."
  type        = string
  default     = null

  validation {
    condition     = var.acm_certificate_arn == null || can(regex("^arn:aws:acm:us-east-1:", var.acm_certificate_arn))
    error_message = "ACM certificate must be in us-east-1 — CloudFront requires this."
  }
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the custom domain. Required if custom_domain is set."
  type        = string
  default     = null
}

variable "enable_logging" {
  description = "Enable CloudFront access logging to an S3 bucket."
  type        = bool
  default     = false
}

variable "enable_cloudfront" {
  description = "Whether to create a CloudFront distribution. Set false for S3 website-only deployments."
  type        = bool
  default     = true
}

variable "website_content" {
  description = "Map of filename => { content, content_type } for files to upload to the bucket. If empty, a default index and error page are created."
  type = map(object({
    content      = string
    content_type = string
  }))
  default = {}
}
