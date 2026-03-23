# Day 4 — State Backend Bootstrap

This folder creates the S3 bucket used for Day-4 Terraform remote state.

## What this creates

- An S3 bucket (name provided by you)
- Versioning enabled (recommended for state recovery)
- Default encryption enabled (SSE-S3 / AES256)
- Public access blocked
- Bucket owner enforced

## Run

```bash
terraform init
terraform apply -var="terraform_day4_bucket=YOUR_GLOBALLY_UNIQUE_BUCKET"
```

## Notes

- The bucket resource includes `force_destroy = true`. If you run `terraform destroy` here, AWS will delete the bucket even if it still contains state objects.
- Once the bucket exists, configure Day-4’s S3 backend and migrate state from the parent folder (see `../README.md`).
