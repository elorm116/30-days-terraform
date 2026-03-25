# 30 Days of Terraform

Small, day-by-day Terraform exercises using AWS.

## Prereqs

- Terraform installed (`terraform version`)
- An AWS account
- AWS credentials available to Terraform (one common option is setting `AWS_PROFILE`)

> Cost note: These examples create real AWS resources (EC2, ALB, Auto Scaling, etc.). Always run `terraform destroy` when you’re done.

## Repo layout

- `Day-1/` — single EC2 web server
- `Day-2/` — placeholder
- `Day-3/` — single EC2 web server (cleaner structure)
- `Day-4-and-5/` — highly available web tier: ALB + Auto Scaling Group (+ optional remote state)
- `Day-7/` — Terraform state isolation: workspaces vs file layouts (+ remote state data source)

## How to run a day

From a given day folder:

```bash
terraform init
terraform apply
```

To tear it down:

```bash
terraform destroy
```

## State files

- Local state files (`terraform.tfstate*`) are ignored via `.gitignore`.
- Day 4/5 supports remote state in S3 with **S3-native locking** (`use_lockfile = true`). See `Day-4-and-5/README.md`.
