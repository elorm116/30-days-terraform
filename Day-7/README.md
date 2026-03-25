# Day 7: Terraform State Isolation — Workspaces vs File Layouts

Yesterday you moved Terraform state to a remote backend. Today’s goal is to manage **multiple environments** (dev/staging/production) without them interfering with each other.

Terraform gives you two common approaches:

- **Workspaces**: multiple state files inside the same backend and the same config directory.
- **File layouts**: separate directories per environment, each with its own backend key (recommended for many production setups).

This day also includes a small **`terraform_remote_state`** demo to show how one stack can read outputs from another.

> Locking note: this repo uses **S3 native locking** via `use_lockfile = true` (modern approach). DynamoDB locking is still valid, but optional.

## Prereqs

- Terraform installed
- AWS credentials configured (e.g. `AWS_PROFILE`, environment variables, etc.)
- An S3 bucket for remote state (you can reuse the one from Day-4-and-5)

## Quick mental model (what you’re isolating)

Terraform remote state in S3 is just **different objects (keys)** in the same bucket.

- **Workspaces** isolate by changing the *workspace name* (same code folder, different state per workspace).
- **File layouts** isolate by changing the *directory/backend key* (different folder per environment, different state key).

## Why you keep seeing `backend.tf` + `backend.hcl`

- `backend.tf` declares the backend type (`s3`) and often hard-codes the **state key** for that stack.
- `backend.hcl` is a **local (gitignored) file** you create that provides backend settings at init time (usually `bucket` and `region`).

This is normal because backend config is evaluated during `terraform init` and **cannot use Terraform variables**.

## Part 1 — State isolation via Workspaces

Folder: `workspaces/`

### What you’ll see

- One config, multiple workspaces (`dev`, `staging`, `production`)
- Instance type and tags change based on `terraform.workspace`
- State is isolated per workspace inside the same S3 backend

### Run

```bash
cd workspaces

# If you don’t already have backend.hcl, create it from the example
cp -n backend.hcl.example backend.hcl

terraform init -backend-config=backend.hcl

terraform workspace new dev
terraform workspace new staging
terraform workspace new production
terraform workspace list

terraform workspace select dev
terraform apply

terraform workspace select staging
terraform apply

terraform workspace select production
terraform apply
```

### Verify state isolation

In S3, you should see separate state objects per workspace. This example sets `workspace_key_prefix = "day-7/workspaces"`, so the keys typically look like:

- `day-7/workspaces/dev/terraform.tfstate`
- `day-7/workspaces/staging/terraform.tfstate`
- `day-7/workspaces/production/terraform.tfstate`

### Destroy

```bash
terraform workspace select dev
terraform destroy

terraform workspace select staging
terraform destroy

terraform workspace select production
terraform destroy
```

## Part 2 — State isolation via File Layouts

Folder: `file-layouts/environments/`

This approach uses a directory per environment. Each environment has its own backend key in S3.

### Run

```bash
cd file-layouts

# If you don’t already have backend.hcl, create it from the example
cp -n backend.hcl.example backend.hcl

cd environments/dev
terraform init -backend-config=../../backend.hcl
terraform apply

cd ../staging
terraform init -backend-config=../../backend.hcl
terraform apply

cd ../production
terraform init -backend-config=../../backend.hcl
terraform apply
```

### Destroy

```bash
cd environments/production
terraform destroy

cd ../staging
terraform destroy

cd ../dev
terraform destroy
```

## Part 3 — Remote State Data Source (`terraform_remote_state`)

Folder: `remote-state/`

This demo has two stacks:

- `remote-state/network/` writes outputs (`vpc_id`, `subnet_id`) into its own remote state
- `remote-state/app/` reads those outputs using `terraform_remote_state` and launches an EC2 instance in that subnet

### Run

```bash
cd remote-state

# Backend config used by both stacks
cp -n backend.hcl.example backend.hcl

# 1) Apply network stack
cd network
terraform init -backend-config=../backend.hcl
terraform apply

# 2) Apply app stack (reads network outputs)
cd ../app
terraform init -backend-config=../backend.hcl
terraform apply -var="state_bucket=YOUR_BUCKET_NAME"
```

### Destroy

```bash
cd app
terraform destroy -var="state_bucket=YOUR_BUCKET_NAME"

cd ../network
terraform destroy
```

## Optional — Create a state bucket (bootstrap)

If you don’t already have an S3 bucket for remote state, the `state-backend/` folder can create one.

```bash
cd state-backend
terraform init
terraform apply -var="bucket_name=YOUR_GLOBALLY_UNIQUE_BUCKET"
```
