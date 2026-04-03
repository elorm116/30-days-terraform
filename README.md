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
- `Day-8/` — environment-based infrastructure layout (dev/production with separate states)
- `Day-10/` — IAM roles, policies, and instance profiles
- `Day-11/` — multi-environment infrastructure with backend configuration
- `Day-12/` — zero-downtime deployments (rolling updates + blue/green switching)
- `Day-13/` — AWS Secrets Manager integration
- `Day-14/` — multi-region infrastructure deployment
- `Day-15/` — multi-provider setup (AWS, Docker, GCP)
- `Day-16/` — additional webserver cluster patterns
- `Day-18/` — **Terraform native testing + Go integration tests** with CI/CD pipeline

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

## Testing

**Day-18** includes comprehensive test infrastructure:

- **Terraform native tests** (`tftest.hcl`): Unit tests using mock providers (no real infrastructure, free, ~10-30 seconds)
- **Go integration tests**: Full end-to-end tests with real AWS resources (auto-cleanup via `defer terraform.Destroy()`)
- **CI/CD pipeline**: Automated testing on every push using GitHub Actions

Run tests locally:
```bash
cd Day-18

# Terraform unit tests (mock provider, fast)
terraform test

# Go integration tests (real AWS, ~10 min, requires credentials)
cd test && go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```

Tests are also automatically run in CI on every push to `main` branch.
