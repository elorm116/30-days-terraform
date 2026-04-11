# envs/production/main.tf
# Production environment calling configuration.
# Same module as dev, but with production-optimized settings.

module "static_website" {
  source = "../../modules/s3-static-website"

  bucket_name    = var.bucket_name
  environment    = var.environment
  index_document = var.index_document
  error_document = var.error_document

  # Production gets global CloudFront coverage
  cloudfront_price_class = var.cloudfront_price_class

  # Optional custom domain support
  custom_domain       = var.custom_domain
  acm_certificate_arn = var.acm_certificate_arn
  route53_zone_id     = var.route53_zone_id

  # Enable access logging in production for audit trail
  enable_logging = true

  # Longer cache TTLs in production
  default_ttl = 86400   # 24 hours
  max_ttl     = 604800  # 7 days

  # Website content with production-specific variables
  website_content = {
    "index.html" = {
      content      = templatefile("${path.module}/templates/index.html.tftpl", {
        environment = var.environment
        bucket_name = var.bucket_name
        day         = "25"
      })
      content_type = "text/html"
    }
    "error.html" = {
      content      = templatefile("${path.module}/templates/error.html.tftpl", {})
      content_type = "text/html"
    }
  }

  tags = {
    Owner      = "mali"
    Day        = "25"
    Challenge  = "30-day-terraform-challenge"
    CostCenter = "personal-learning"
    Env        = "production"
  }
}
