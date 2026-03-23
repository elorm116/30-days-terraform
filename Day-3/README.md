# 30-Day Terraform Challenge — Day 3

## Goal

Provision a single EC2 instance in AWS and bootstrap a simple Apache web page using `user_data`.

## What this creates

- Looks up the default VPC
- Creates a Security Group allowing inbound HTTP (port 80)
- Finds the latest Amazon Linux 2023 AMI
- Creates an EC2 instance and outputs its public IP

## Prereqs

- Terraform installed
- AWS credentials configured

## Run

```bash
terraform init
terraform apply
```

## Test

Terraform outputs `ec2_instance_ip`. Open:

```text
http://<ec2_instance_ip>
```

## Destroy

```bash
terraform destroy
```
