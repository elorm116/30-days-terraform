# 30-Day Terraform Challenge — Day 4 (Highly Available)

This day builds a simple highly-available web tier using an Application Load Balancer (ALB) and an Auto Scaling Group (ASG).

## Architecture (high level)

- **ALB (public)** listens on `var.alb_port` (default: 80)
- **Target Group** forwards to instances on `var.server_port` (default: 8080)
- **ASG** keeps 2 instances running (desired capacity) across your default VPC subnets
- **Launch Template** bootstraps Apache and serves a static HTML page

## What this creates

- Data sources: default VPC, subnets, AZs, latest Amazon Linux 2023 AMI
- Security groups:
  - ALB SG: inbound from the internet to port 80
  - Instance SG: inbound only from the ALB SG to port 8080
- ALB + Listener + Listener Rule
  - Listener default action returns a fixed 404
  - Listener rule forwards all paths (`*`) to the target group
- Target group health checks: `GET /` expecting HTTP 200
- Auto Scaling Group attached to the target group

## Prereqs

- Terraform installed
- AWS credentials configured

## Run (local state)

```bash
terraform init
terraform apply
```

## Test

After apply, Terraform outputs `alb_dns_name`.

Open:

```text
http://<alb_dns_name>
```

## Destroy

```bash
terraform destroy
```

## Optional: Remote state in S3 (modern locking)

This folder is configured with an S3 backend stub in `backend.tf`. Supply the real backend settings via `backend.hcl`.

### 1) Create an S3 bucket for state

Use the bootstrap configuration in `state-backend/`:

```bash
cd state-backend
terraform init
terraform apply -var="terraform_day4_bucket=YOUR_GLOBALLY_UNIQUE_BUCKET"
```

Note: the bootstrap bucket resource uses `force_destroy = true`, meaning Terraform can delete the bucket even if it contains objects.

### 2) Configure the backend

Create `backend.hcl` (do not commit it):

```hcl
bucket = "YOUR_GLOBALLY_UNIQUE_BUCKET"
key    = "Day-4/terraform.tfstate"
region = "us-east-1"

encrypt      = true
use_lockfile = true
```

### 3) Migrate state

From `Day-4/`:

```bash
terraform init -backend-config=backend.hcl -migrate-state
```

After that, `terraform plan/apply/destroy` will use the remote state in S3.
