# Bootstrap Configuration

This folder creates the S3 bucket for storing Terraform state for Day-25.

## What Gets Created

**S3 Bucket** (`mali-terraform-state-day25`)
- Stores Terraform state files
- Versioning enabled (rollback capability)
- Encryption enabled (AES256)
- Public access blocked
- Logging enabled

## State Locking

Uses native lock files (`use_lockfile = true`) instead of DynamoDB:
- ✅ Simpler setup
- ✅ No additional AWS resources
- ✅ Perfect for small teams
- ✅ Lock files stored in S3 alongside state

## Prerequisites

- AWS credentials configured with `aws configure`
- Terraform 1.10+
- AWS account with permissions to create S3 buckets

## Quick Start

```bash
cd bootstrap/

# Initialize Terraform (no backend needed for bootstrap)
terraform init

# Review what will be created
terraform plan

# Create the state bucket
terraform apply
```

## Output Example

```
state_bucket_name = "mali-terraform-state-day25"

backend_config = {
  bucket       = "mali-terraform-state-day25"
  key          = "day25/static-website/terraform.tfstate"
  region       = "us-east-1"
  encrypt      = true
  use_lockfile = true
}
```

## Next Steps

1. ✅ Run bootstrap: `cd bootstrap && terraform apply`
2. ✅ Deploy Day-25: `cd envs/dev && terraform init && terraform apply`

## Cost

- S3: ~$0.50/month (storage only)
- Total: ~$0.50/month

## Important Notes

- ⚠️ **prevent_destroy = true** on S3 bucket
  - Prevents accidental deletion of state
  - To destroy: set `prevent_destroy = false` in main.tf first
  
- 🔐 Bootstrap state is stored locally in `.terraform/`
  - Later you can migrate it to S3 if needed
