
# envs/dev/main.tf
# Dev environment calling configuration.
# This file is intentionally thin — all complexity lives in the module.
# The dev environment simply wires together variables and the module.

module "static_website" {
  source = "../../modules/s3-static-website"

  bucket_name    = var.bucket_name
  environment    = var.environment
  index_document = var.index_document
  error_document = var.error_document

  # Dev uses the cheapest CloudFront price class (US + EU only)
  # Production would use PriceClass_200 or PriceClass_All
  cloudfront_price_class = var.cloudfront_price_class

  # Custom domain is optional — uncomment and set variables to enable
  # custom_domain       = var.custom_domain
  # acm_certificate_arn = var.acm_certificate_arn
  # route53_zone_id     = var.route53_zone_id

  # No access logging in dev — reduces cost and noise
  enable_logging = false

  # Temporary fallback: account is not yet verified for CloudFront creation.
  # This allows a working S3 static website deploy until AWS enables CloudFront.
  enable_cloudfront = false

  # Website content — providing custom HTML for the challenge
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
  }
}
