# Day 7 — Optional State Bucket Bootstrap

You can reuse the same S3 bucket you created earlier (Day-4-and-5). If you *don’t* have one yet, this folder creates an S3 bucket suitable for Terraform remote state.

## What it creates

- S3 bucket (name you provide)
- Versioning enabled
- Default encryption (SSE-S3 / AES256)
- Public access blocked

## Run

```bash
terraform init
terraform apply -var="bucket_name=YOUR_GLOBALLY_UNIQUE_BUCKET"
```

## Notes

- This uses `force_destroy = true` for learning. That means `terraform destroy` can delete the bucket even if it contains state objects.
- In production, you usually want additional safeguards (like preventing accidental deletion).
