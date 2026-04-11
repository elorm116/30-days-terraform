output "bucket_name" {
  description = "Name of the S3 website bucket"
  value       = module.static_website.bucket_name
}

output "bucket_arn" {
  description = "ARN of the S3 website bucket"
  value       = module.static_website.bucket_arn
}

output "website_endpoint" {
  description = "S3 website endpoint URL (HTTP only — use CloudFront for HTTPS)"
  value       = module.static_website.website_endpoint
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name — primary access URL (HTTPS)"
  value       = module.static_website.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — needed for cache invalidations"
  value       = module.static_website.cloudfront_distribution_id
}

output "invalidation_command" {
  description = "AWS CLI command to invalidate CloudFront cache after updates"
  value       = module.static_website.invalidation_command
}
