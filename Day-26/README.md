# Day 26 — Modular Web App (ALB + ASG + Launch Template)

This day builds a small, production-shaped AWS web stack using **three Terraform modules**:

- **ALB module**: public entry point (ALB + target group + listeners + ALB security group)
- **EC2 module**: instance security group + launch template (includes user data)
- **ASG module**: Auto Scaling Group + scaling policies + CPU alarms + CloudWatch dashboard

> Assignment note: you run **dev** only. A **production** environment root is included as a reference.

---

## Layout

- `envs/dev/` — dev root module (the one you run)
- `envs/production/` — production-style root module (reference only)
- `modules/alb/` — ALB + target group + listeners + ALB SG
- `modules/ec2/` — instance SG + launch template + `user_data.sh`
- `modules/asg/` — ASG + alarms + dashboard

---

## How to run (Dev)

Run Terraform from the dev root module:

```bash
cd Day-26/envs/dev
terraform init
terraform plan
terraform apply
```

After apply, outputs are defined in `envs/dev/outputs.tf`.

If `terraform output` prints **"No outputs found"**, that usually means the state was created before outputs existed or outputs haven’t been refreshed. Fix with:

```bash
terraform apply -refresh-only
terraform output
```

---

## Production (Reference)

The production root exists to show how teams typically separate environments and state.

It validates without touching AWS state like this:

```bash
cd Day-26/envs/production
terraform init -backend=false
terraform validate
```

Do **not** `apply` production unless you replace the placeholder values in `envs/production/terraform.tfvars`.

---

## Issues We Hit (And Fixes)

### 1) `terraform validate` failed: invalid Security Group description characters

**Symptom**: AWS provider rejected the security group rule description.

**Cause**: Some AWS fields enforce an allowlist of characters. The ALB security group `egress.description` used an em dash.

**Fix**: replaced the em dash with a normal hyphen.

Where:
- `modules/alb/main.tf`

---

### 2) EC2 module failed: missing `user_data.sh`

**Symptom**: Terraform couldn’t render user data from the EC2 module.

**Cause**: The launch template used `templatefile("${path.module}/user_data.sh", ...)` but the file didn’t exist in `modules/ec2/`.

**Fix**: added `modules/ec2/user_data.sh`.

Where:
- `modules/ec2/main.tf`
- `modules/ec2/user_data.sh`

---

### 3) `templatefile()` failed parsing Bash syntax in user data

**Symptom**: `templatefile()` reported an invalid character / template parse error.

**Cause**: Terraform’s template engine treats `${...}` as template interpolation. A Bash array expansion `${IMDS_HEADER[@]}` was interpreted as a Terraform template expression.

**Fix**: rewrote the metadata calls to avoid Bash `${...}` patterns that confuse Terraform templates.

Where:
- `modules/ec2/user_data.sh`

---

### 4) CloudWatch dashboard warning: deprecated region attribute

**Symptom**: validation warnings about `data.aws_region.current.name` being deprecated.

**Fix**: switched dashboard widget region to `data.aws_region.current.id`.

Where:
- `modules/asg/main.tf`

---

### 5) `terraform apply` failed: `t3.micro` not supported in `us-east-1e`

**Symptom**:

> Your requested instance type (t3.micro) is not supported in your requested Availability Zone (us-east-1e)

**Cause**: Dev auto-discovered **all** default-VPC subnets, including an AZ that doesn’t offer `t3.micro` in your account.

**Fix**: added `excluded_availability_zones` so subnet auto-discovery can filter out problematic AZs.

Where:
- `envs/dev/variables.tf` (new variable)
- `envs/dev/main.tf` (subnet discovery + filtering)
- `envs/dev/terraform.tfvars` (set `excluded_availability_zones = ["us-east-1e"]`)

---

### 6) `terraform apply` failed: ASG AlreadyExists

**Symptom**:

> AlreadyExists: AutoScalingGroup by this name already exists

**Cause**: The ASG resource was **tainted**, so Terraform tried to replace it. Because the ASG name is fixed (not name_prefix), the replacement attempted to create a new ASG with the same name and AWS rejected it.

**Fix**: untainted the ASG so Terraform updated it in-place.

Command:

```bash
cd Day-26/envs/dev
terraform untaint module.asg.aws_autoscaling_group.web
```

