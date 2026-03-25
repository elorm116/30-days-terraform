# Day 7 — Terraform State Isolation

Part of the [30 Day Terraform Challenge](https://github.com).

This project demonstrates two approaches to Terraform state isolation
across multiple environments (dev, staging, production), plus the
remote state data source pattern for layered infrastructure.

## What This Covers

- State isolation via Workspaces
- State isolation via File Layouts
- Remote State Data Source (`terraform_remote_state`)
- Shared S3 remote backend with native locking

## Project Structure
```
Day-7/
├── state-backend/              # Provisions shared S3 bucket — run first
├── workspaces/                 # Approach 1: workspace isolation
├── file-layouts/
│   └── environments/
│       ├── dev/                # Approach 2: file layout isolation
│       ├── staging/
│       └── production/
└── remote-state/
    ├── network/                # Creates VPC and subnet, outputs IDs
    └── app/                    # Reads network state, deploys EC2
```

## Prerequisites

- Terraform >= 1.10
- AWS CLI configured with valid credentials
- An AWS account with EC2 and S3 permissions

## Usage

### Step 1 — Provision the State Backend
```bash
cd state-backend
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your bucket name
terraform init
terraform apply
```

### Step 2 — Workspaces
```bash
cd workspaces
cp backend.hcl.example backend.hcl
# Edit backend.hcl with your bucket name
terraform init -backend-config=backend.hcl

terraform workspace new dev
terraform workspace new staging
terraform workspace new production

terraform workspace select dev && terraform apply
terraform workspace select staging && terraform apply
terraform workspace select production && terraform apply
```

### Step 3 — File Layouts
```bash
# Each environment is deployed independently
cd file-layouts/environments/dev
terraform init -backend-config=backend.hcl
terraform apply

cd ../staging
terraform init -backend-config=backend.hcl
terraform apply

cd ../production
terraform init -backend-config=backend.hcl
terraform apply
```

### Step 4 — Remote State
```bash
# Network layer must be deployed first
cd remote-state/network
terraform init -backend-config=backend.hcl
terraform apply

# App layer reads network outputs from S3 state
cd ../app
terraform init -backend-config=backend.hcl
terraform apply
```

## Destroy Order

Always destroy in reverse order — the state bucket must be last:
```bash
# 1. Remote state
cd remote-state/app && terraform destroy
cd ../network && terraform destroy

# 2. File layouts
cd file-layouts/environments/production && terraform destroy
cd ../staging && terraform destroy
cd ../dev && terraform destroy

# 3. Workspaces
cd workspaces
terraform workspace select production && terraform destroy
terraform workspace select staging && terraform destroy
terraform workspace select dev && terraform destroy

# 4. State backend — always last
cd state-backend && terraform destroy
```

## Key Concepts

**Workspaces** — same code, multiple state files managed by Terraform
under `env:/<workspace>/` paths in S3. Good for quick experiments,
not recommended for production.

**File Layouts** — separate directory per environment, each with its
own backend config pointing to a unique S3 key. Full isolation,
recommended for production.

**Remote State Data Source** — allows one Terraform config to read
outputs from another config's state file. Used here so the app layer
can consume VPC and subnet IDs created by the network layer without
hardcoding.

## Notes

- `backend.hcl` files are gitignored — use `backend.hcl.example` as a template
- `us-east-1e` does not support `t2.micro` or `t3.micro` — subnets are
  pinned to `us-east-1a` to avoid this
- S3 native locking (`use_lockfile = true`) requires Terraform >= 1.10