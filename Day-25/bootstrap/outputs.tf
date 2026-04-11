output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "Region of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.region
}

output "backend_config" {
  description = "Backend configuration to use in terraform block"
  value = {
    bucket       = aws_s3_bucket.terraform_state.id
    key          = "day25/static-website/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
