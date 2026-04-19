# Terragrunt Static Site

Standalone Terragrunt project for a static website module deployment.

## Layout

- modules/s3-static-website: Terraform module
- live/terragrunt.hcl: Shared remote state, provider generation, common inputs
- live/dev/terragrunt.hcl: Dev inputs
- live/production/terragrunt.hcl: Production inputs

## Prerequisites

- Terraform >= 1.10
- Terragrunt installed
- AWS credentials configured
- S3 state bucket exists: mali-terraform-state-day25

## Run

### Dev

cd live/dev
terragrunt init
terragrunt plan
terragrunt apply

### Production

cd live/production
terragrunt init
terragrunt plan
terragrunt apply

## Notes

- State key is auto-derived from folder path with path_relative_to_include().
- Remote state uses use_lockfile = true.
- Dev has enable_cloudfront = false to avoid CloudFront account verification blockers.
