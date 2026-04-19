include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = include.root.locals.module_source
}

inputs = {
  environment            = "production"
  bucket_name            = "tg-static-site-prod-mali"
  cloudfront_price_class = "PriceClass_All"

  enable_cloudfront = true
  enable_logging    = true
  default_ttl       = 86400
  max_ttl           = 604800

  custom_domain       = null
  acm_certificate_arn = null
  route53_zone_id     = null

  website_content = {
    "index.html" = {
      content      = <<HTML
<!DOCTYPE html>
<html>
<head><title>Terragrunt Production</title></head>
<body style="font-family: sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem;">
  <h1>Terragrunt Static Site (Production)</h1>
  <p>Environment: production</p>
  <p>Global CDN path configured (CloudFront)</p>
</body>
</html>
HTML
      content_type = "text/html"
    }
    "error.html" = {
      content      = <<HTML
<!DOCTYPE html>
<html>
<head><title>404</title></head>
<body style="font-family: sans-serif; padding: 2rem;"><h1>404</h1><p>Page not found.</p></body>
</html>
HTML
      content_type = "text/html"
    }
  }
}
