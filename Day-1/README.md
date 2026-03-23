![Terraform](https://img.shields.io/badge/IaC-Terraform-blue)

# 30-Day Terraform Challenge — Day 1

## Goal

Provision a single EC2 instance running a basic Apache web page.

## What this creates

- Default VPC lookup (data source)
- Security Group allowing inbound HTTP (port 80)
- EC2 instance (Amazon Linux 2023) with `user_data` that installs and starts Apache
- Output of the instance public IP

## Prereqs

- Terraform installed
- AWS credentials configured (environment variables, AWS profile, etc.)

## Run

From this folder:

```bash
terraform init
terraform apply
```

## Test

After apply, Terraform prints `ec2_instance_ip`. Open:

```text
http://<ec2_instance_ip>
```

## Destroy

```bash
terraform destroy
```
