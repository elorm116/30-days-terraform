
locals {
  common_tags = merge(var.tags, {
    ManagedBy   = "Terraform"
    Environment = var.environment
    Project     = "static-website"
  })

  # Production gets global edge coverage; dev/staging stay in US+EU only
  price_class = var.cloudfront_price_class

  # Allow force_destroy in non-production environments so terraform destroy works cleanly
  force_destroy = var.environment != "production"

  # Determine if a custom domain is being used
  has_custom_domain = var.custom_domain != null && var.acm_certificate_arn != null

  # Default HTML content used when no website_content is provided
  default_index_html = <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Deployed with Terraform</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          background: #0d1117;
          color: #c9d1d9;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
        }
        .card {
          background: #161b22;
          border: 1px solid #30363d;
          border-radius: 12px;
          padding: 2.5rem 3rem;
          max-width: 500px;
          width: 90%;
          text-align: center;
        }
        .badge {
          display: inline-block;
          background: #1f6feb;
          color: #fff;
          font-size: 0.75rem;
          padding: 0.25rem 0.75rem;
          border-radius: 20px;
          margin-bottom: 1.5rem;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }
        .badge.prod { background: #3fb950; color: #0d1117; }
        .badge.staging { background: #d29922; color: #0d1117; }
        h1 { font-size: 1.75rem; font-weight: 600; margin-bottom: 0.5rem; }
        p { color: #8b949e; line-height: 1.6; margin-bottom: 0.5rem; font-size: 0.95rem; }
        .meta { margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid #30363d; }
        .meta span { font-family: monospace; color: #79c0ff; font-size: 0.85rem; }
        .footer { margin-top: 2rem; font-size: 0.8rem; color: #484f58; }
      </style>
    </head>
    <body>
      <div class="card">
        <span class="badge ${var.environment}">${var.environment}</span>
        <h1>Deployed with Terraform</h1>
        <p>This static website was deployed using Terraform as part of the 30-Day Terraform Challenge.</p>
        <div class="meta">
          <p>Bucket: <span>${var.bucket_name}</span></p>
          <p>Environment: <span>${var.environment}</span></p>
          <p>Day: <span>25 — S3 + CloudFront</span></p>
        </div>
        <p class="footer">Served via CloudFront CDN &middot; Managed by Terraform</p>
      </div>
    </body>
    </html>
  HTML

  default_error_html = <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>404 — Not Found</title>
      <style>
        body { font-family: -apple-system, sans-serif; background: #0d1117; color: #c9d1d9; display: flex; align-items: center; justify-content: center; min-height: 100vh; }
        .card { text-align: center; }
        h1 { font-size: 5rem; font-weight: 700; color: #30363d; margin-bottom: 0.5rem; }
        p { color: #8b949e; }
        a { color: #79c0ff; text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>404</h1>
        <p>Page not found.</p>
        <p><a href="/">Go home</a></p>
      </div>
    </body>
    </html>
  HTML

  # Merge default content with any caller-provided content
  all_content = length(var.website_content) > 0 ? var.website_content : {
    "index.html" = { content = local.default_index_html, content_type = "text/html" }
    "error.html" = { content = local.default_error_html, content_type = "text/html" }
  }
}

# ─── S3 Bucket ────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = local.force_destroy
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    # Versioning on static website assets provides rollback capability.
    # Suspended in dev to reduce storage costs; enabled in production.
    status = var.environment == "production" ? "Enabled" : "Suspended"
  }
}

# ── Website configuration ──────────────────────────────────────────────────────

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

# ── Public access — required for S3 website hosting ───────────────────────────
# S3 website hosting requires public read access. We explicitly unblock it and
# then add a bucket policy granting s3:GetObject to everyone.
# NOTE: For production, prefer an OAC (Origin Access Control) CloudFront setup
# that keeps the bucket private. The S3 website endpoint approach is simpler
# and sufficient for this challenge but does expose the bucket directly.

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json

  # The public access block must be disabled before the bucket policy can be applied
  depends_on = [aws_s3_bucket_public_access_block.website]
}

data "aws_iam_policy_document" "website" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]
  }
}

# ── Website content ───────────────────────────────────────────────────────────

resource "aws_s3_object" "content" {
  for_each = local.all_content

  bucket       = aws_s3_bucket.website.id
  key          = each.key
  content      = each.value.content
  content_type = each.value.content_type

  # Invalidate cache when content changes
  etag = md5(each.value.content)
}

# ─── Optional: CloudFront Access Logging Bucket ───────────────────────────────

resource "aws_s3_bucket" "logs" {
  count = var.enable_cloudfront && var.enable_logging ? 1 : 0

  bucket        = "${var.bucket_name}-cf-logs"
  force_destroy = local.force_destroy
  tags          = merge(local.common_tags, { Purpose = "CloudFront-Logs" })
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  count  = var.enable_cloudfront && var.enable_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# ─── CloudFront Distribution ──────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "website" {
  count = var.enable_cloudfront ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.index_document
  price_class         = local.price_class
  comment             = "${var.bucket_name} (${var.environment}) — managed by Terraform"
  aliases             = local.has_custom_domain ? [var.custom_domain] : []
  tags                = local.common_tags

  # ── Origin: S3 website endpoint ───────────────────────────────────────────
  # Using the S3 website endpoint (not the REST endpoint) because:
  # 1. It serves index.html for directory paths (e.g. /blog/ → /blog/index.html)
  # 2. It returns the configured error document for 404s
  # The tradeoff: the bucket must allow public access.
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "S3-website-${var.bucket_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"   # S3 website endpoint is HTTP only
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ── Default cache behaviour ────────────────────────────────────────────────
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-website-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"   # Always serve over HTTPS

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = var.default_ttl
    max_ttl     = var.max_ttl

    # Security headers function could be added here in production
    # function_association { ... }
  }

  # ── Custom error responses ─────────────────────────────────────────────────
  # Map S3 403 (access denied on missing object) to 404 + error page
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/${var.error_document}"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/${var.error_document}"
    error_caching_min_ttl = 10
  }

  # ── Geo restrictions ───────────────────────────────────────────────────────
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # ── TLS certificate ────────────────────────────────────────────────────────
  viewer_certificate {
    # Use custom ACM cert if provided; otherwise use CloudFront's default cert
    cloudfront_default_certificate = !local.has_custom_domain
    acm_certificate_arn            = local.has_custom_domain ? var.acm_certificate_arn : null
    ssl_support_method             = local.has_custom_domain ? "sni-only" : null
    minimum_protocol_version       = local.has_custom_domain ? "TLSv1.2_2021" : null
  }

  # ── Access logging ─────────────────────────────────────────────────────────
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      bucket          = aws_s3_bucket.logs[0].bucket_domain_name
      include_cookies = false
      prefix          = "cloudfront/"
    }
  }

  # CloudFront distributions can take 5-15 minutes to deploy globally
  # Terraform waits for the distribution to reach Deployed status
  wait_for_deployment = true

  depends_on = [aws_s3_bucket_policy.website]
}

# ─── Route53 DNS Record (optional) ───────────────────────────────────────────

resource "aws_route53_record" "website" {
  count = var.enable_cloudfront && local.has_custom_domain && var.route53_zone_id != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.custom_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website[0].domain_name
    zone_id                = aws_cloudfront_distribution.website[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# www redirect record (if custom domain is set)
resource "aws_route53_record" "website_www" {
  count = var.enable_cloudfront && local.has_custom_domain && var.route53_zone_id != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = "www.${var.custom_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.website[0].domain_name]
}
