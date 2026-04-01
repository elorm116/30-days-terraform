# Day 12 — Zero-Downtime Deployments with Terraform

Part of the [30 Day Terraform Challenge](https://github.com).

Implements two zero-downtime deployment strategies:
1. Rolling updates via `instance_refresh`
2. Blue/green traffic switching via ALB listener rules

## What This Demonstrates

- Why default Terraform causes downtime during infrastructure updates
- How `create_before_destroy` reverses the destroy-then-create order
- Why `name_prefix` is required on ASGs with `create_before_destroy`
- How `instance_refresh` triggers rolling instance replacement
- How blue/green switching works at the ALB listener rule level

## Project Structure
```
Day-12/
└── webserver-cluster/
    ├── main.tf         ← all resources with lifecycle rules
    ├── variables.tf    ← app_version and active_environment variables
    ├── outputs.tf      ← ALB DNS, ASG name, TG ARNs
    ├── backend.tf      ← S3 remote backend
    └── backend.hcl     ← bucket config (gitignored)
```

## Prerequisites

- Terraform >= 1.10
- AWS CLI configured
- S3 bucket for remote state (`dark-knight-terraform-state`)

## Usage

### Initial Deployment (v1)
```bash
cd Day-12/webserver-cluster
terraform init -backend-config=backend.hcl
terraform apply
```

### Zero-Downtime Update (v1 → v2)

Open Terminal 2 and start traffic loop:
```bash
while true; do
  curl -s http://<alb-dns-name>
  echo " — $(date +%H:%M:%S)"
  sleep 2
done
```

In Terminal 1 update `terraform.tfvars`:
```hcl
app_version = "v2"
```
```bash
terraform apply
```

Watch Terminal 2 — responses roll from v1 to v2 with no errors.

### Blue/Green Traffic Switch
```hcl
# terraform.tfvars
active_environment = "green"  # or "blue"
```
```bash
terraform apply  # completes in ~8 seconds
```

Traffic shifts instantly at the ALB listener rule level.

### Destroy
```bash
terraform destroy
```

## Key Variables

| Variable | Description | Default |
|---|---|---|
| app_version | Triggers rolling update when changed | v1 |
| active_environment | Controls blue/green traffic | blue |
| min_size | Minimum ASG instances | 2 |
| max_size | Maximum ASG instances | 4 |
| instance_type | EC2 instance type | t3.micro |

## How instance_refresh Works
```
min_healthy_percentage = 50  → with 2 instances, always keep 1 healthy
instance_warmup = 60         → give new instances 60s before health checks

Step 1: Terminate instance 1 (1 remaining = 50% healthy ✅)
Step 2: Launch new v2 instance
Step 3: Wait 60 seconds
Step 4: Wait for health checks to pass
Step 5: Terminate instance 2
Step 6: Launch second v2 instance
Step 7: Complete
```

## Limitations

- Double instance cost during rolling update transition
- instance_refresh runs async — Terraform doesn't wait for completion
- Blue/green in this setup uses same instances in both TGs
  — true blue/green requires separate ASGs per environment
- No canary/weighted routing — traffic shift is all-or-nothing

## Notes

- `backend.hcl` is gitignored — use `backend.hcl.example` as template
- Excludes `us-east-1e` — does not support `t3.micro`
- Wait 2-3 minutes after initial deploy for health checks to pass
- `triggers = ["launch_template"]` is required in `instance_refresh`
  despite the Terraform warning — without it refreshes don't fire