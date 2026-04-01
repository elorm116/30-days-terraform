# Day 10 — Terraform Loops, Conditionals, and a Webserver Cluster

Day 10 contains two independent Terraform stacks:

- `iam/`: Demonstrates `count` vs `for_each` (set and map), plus `for` expressions in outputs.
- `webserver-cluster/`: Builds a simple highly-available web tier (ALB + ASG) and demonstrates conditionals/feature toggles with `count`, plus `locals` for centralized decision logic.

> Run Terraform **from inside** each folder. They do not share state.

---

## Prerequisites

- Terraform installed (any recent 1.x should work; the webserver stack pins the AWS provider to `~> 6.37`).
- AWS credentials available to Terraform, e.g. one of:
  - `AWS_PROFILE` set to a configured profile, or
  - `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` exported.
- An AWS account with permissions to create IAM users (for `iam/`) and VPC/EC2/ALB/ASG/CloudWatch resources (for `webserver-cluster/`).

Region is hardcoded to `us-east-1` in both stacks.

---

## Folder layout

```
Day-10/
  README.md
  iam/
    main.tf
    variables.tf
    outputs.tf
  webserver-cluster/
    backend.tf
    backend.hcl
    main.tf
    variables.tf
    outputs.tf
    terraform.tfvars
```

---

## Stack 1: `iam/` — `count` vs `for_each`

### What it creates

`iam/main.tf` creates **three sets** of IAM users (same names, different meta-prefixes) to show how addressing differs:

- `aws_iam_user.count_users` uses `count` with a **list** (`var.user_names_list`)
  - Addresses are index-based: `aws_iam_user.count_users[0]`, `[1]`, ...
  - Reordering/removing items can cause unexpected recreation because indexes shift.
- `aws_iam_user.set_users` uses `for_each` with a **set** (`var.user_names_set`)
  - Addresses are key-based: `aws_iam_user.set_users["mali"]`, ...
  - Removing one element typically removes only that resource.
- `aws_iam_user.map_users` uses `for_each` with a **map(object)** (`var.users`)
  - Demonstrates passing extra per-user configuration (department/admin) via `each.value`.

### Inputs

All inputs have defaults in `iam/variables.tf`, so you can run this stack without providing variables.

Key variables:

- `user_names_list` (list of strings)
- `user_names_set` (set of strings)
- `users` (map of objects: `{ department = string, admin = bool }`)

### Outputs

`iam/outputs.tf` includes:

- `count_user_arns`: list of ARNs from the `count` users
- `set_user_arns`: map of username → ARN from the `for_each` set users
- `map_user_arns`: map of username → ARN from the `for_each` map users
- `uppercase_usernames`, `user_departments`, `admin_users`: examples of `for` expressions (including filtering with `if`)

### Run it

```bash
cd Day-10/iam
terraform init
terraform plan
terraform apply
```

Clean up:

```bash
terraform destroy
```

---

## Stack 2: `webserver-cluster/` — ALB + ASG with conditional autoscaling

### What it creates

This stack is a small, production-shaped web tier using the **default VPC**:

- Data sources:
  - Default VPC and its subnets
  - Available AZs (explicitly excludes a legacy AZ ID)
  - Latest Amazon Linux 2023 AMI (`most_recent = true`)
- Networking:
  - ALB security group: allows inbound HTTP (`var.alb_port`, default 80) from the internet
  - Instance security group: allows inbound only from the ALB SG on `var.server_port` (default 8080)
- Compute:
  - Launch template with `user_data` that installs `httpd`, changes its Listen port, and writes a simple HTML page
  - Auto Scaling Group attached to the ALB target group
- Load balancing:
  - Application Load Balancer + listener + listener rule forwarding `/*` to the target group
- Optional autoscaling:
  - Autoscaling policies + CloudWatch alarms are created only when `var.enable_autoscaling = true`
  - Thresholds are controlled via `locals` and vary by `var.environment`:
    - scale out: 70 (production) / 90 (non-production)
    - scale in: 30 (production) / 20 (non-production)

### Remote state (S3 backend)

`webserver-cluster/backend.tf` declares an `s3` backend, and `webserver-cluster/backend.hcl` supplies the backend settings.

You must have the referenced S3 bucket created already:

- Bucket: `dark-knight-terraform-state`
- State key: `day10/webserver-cluster/terraform.tfstate`

If the bucket doesn’t exist, `terraform init` will fail until you create it (or change `backend.hcl`).

### Inputs

Required variables (no defaults):

- `cluster_name`
- `min_size`
- `max_size`

Common optional variables:

- `instance_type` (default `t3.micro`)
- `server_port` (default `8080`)
- `alb_port` (default `80`)
- `custom_message` (default `Highly Available`)
- `enable_autoscaling` (default `true`)
- `environment` (default `dev`)

This repo includes `webserver-cluster/terraform.tfvars` as an example configuration.

### Outputs

`webserver-cluster/outputs.tf` includes:

- `alb_dns_name`: paste into your browser
- `asg_name`, `alb_arn`
- `autoscaling_enabled`
- `alarm_thresholds`: shows the thresholds selected via `locals`

### Run it

```bash
cd Day-10/webserver-cluster
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

After apply, open the `alb_dns_name` output in your browser.

Clean up:

```bash
terraform destroy
```

---

## Notes on sensitive files (recommended)

Terraform commonly produces files you typically **should not commit**, including:

- `.terraform/`
- `terraform.tfstate*`
- `terraform.tfvars` / `*.tfvars*` (often contains secrets)
- `backend.hcl` (often environment-specific)

If you plan to commit Day-10 to git, consider adding a `.gitignore` (at repo root and/or inside `Day-10/`) to keep those artifacts out of version control.

---

## Troubleshooting

- **`terraform init` fails for the webserver stack**: confirm the S3 bucket in `backend.hcl` exists and your AWS identity has access.
- **No page in browser / unhealthy targets**: give instances a minute to boot; the ASG uses ELB health checks with a grace period.
- **Scaling resources not created**: ensure `enable_autoscaling = true` (policies/alarms are gated by `count`).
