include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = include.root.locals.module_source
}

inputs = {
  environment            = "dev"
  bucket_name            = "tg-static-site-dev-mali"
  cloudfront_price_class = "PriceClass_100"

  # Keep dev deployable in accounts without CloudFront verification.
  enable_cloudfront = false
  enable_logging    = false

  website_content = {
    "index.html" = {
      content      = <<HTML
<!DOCTYPE html>
<html>
<head><title>Terragrunt Dev</title></head>
<body style="font-family: sans-serif; background: #f8fafc; color: #0f172a; padding: 2rem;">
  <h1>Terragrunt Static Site (Dev)</h1>
  <p>Environment: dev</p>
  <p>Managed by Terragrunt + Terraform module</p>
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
