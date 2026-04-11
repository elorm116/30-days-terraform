
output "bucket_name" {
  description = "Name of the S3 website bucket"
  value       = aws_s3_bucket.website.id
}

output "bucket_arn" {
  description = "ARN of the S3 website bucket"
  value       = aws_s3_bucket.website.arn
}

output "website_endpoint" {
  description = "S3 website endpoint URL (HTTP only — use the CloudFront URL for HTTPS)"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name — primary access URL (HTTPS)"
  value       = var.enable_cloudfront ? "https://${aws_cloudfront_distribution.website[0].domain_name}" : null
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — needed to trigger cache invalidations"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.website[0].id : null
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.website[0].arn : null
}

output "cloudfront_status" {
  description = "CloudFront distribution deployment status (Deployed or InProgress)"
  value       = var.enable_cloudfront ? aws_cloudfront_distribution.website[0].status : null
}

output "custom_domain_url" {
  description = "Custom domain URL if configured, otherwise null"
  value       = var.enable_cloudfront && var.custom_domain != null ? "https://${var.custom_domain}" : null
}

output "environment" {
  description = "Environment this website was deployed into"
  value       = var.environment
}

output "invalidation_command" {
  description = "AWS CLI command to invalidate the CloudFront cache after content updates"
  value       = var.enable_cloudfront ? "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.website[0].id} --paths '/*'" : null
}
