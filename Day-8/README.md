# Day 8 — Terraform Modules

Part of the [30 Day Terraform Challenge](https://github.com).

Refactors the web server cluster from Days 3-5 into a reusable
Terraform module deployed across dev and production environments.

## What This Covers

- Building a reusable Terraform module
- Module inputs (variables) and outputs
- Calling a module from multiple environments
- Resource naming conventions for multi-environment deployments
- Separate state files per environment via S3 remote backend

## Project Structure
```
Day-8/
├── modules/
│   └── services/
│       └── webserver-cluster/   ← reusable module
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── README.md
└── live/
    ├── dev/
    │   └── services/
    │       └── webserver-cluster/   ← calls module with dev values
    │           ├── main.tf
    │           ├── backend.tf
    │           └── backend.hcl
    └── production/
        └── services/
            └── webserver-cluster/   ← calls module with production values
                ├── main.tf
                ├── backend.tf
                └── backend.hcl
```

## What the Module Provisions

- ALB security group (internet → port 80)
- EC2 security group (ALB only → port 8080)
- Launch template (Amazon Linux 2023 + httpd)
- Application Load Balancer
- Target group with health checks
- ALB listener with 404 default action
- ALB listener rule (forwards /* to target group)
- Auto Scaling Group with ELB health checks

## Prerequisites

- Terraform >= 1.10
- AWS CLI configured with valid credentials
- S3 bucket for remote state (reuses `dark-knight-terraform-state`)

## Usage

### Deploy Dev
```bash
cd live/dev/services/webserver-cluster
terraform init -backend-config=backend.hcl
terraform apply
```

### Deploy Production
```bash
cd live/production/services/webserver-cluster
terraform init -backend-config=backend.hcl
terraform apply
```

### Destroy

Always destroy in order — production first, then dev:
```bash
cd live/production/services/webserver-cluster
terraform destroy

cd ../../../../live/dev/services/webserver-cluster
terraform destroy
```

## Module Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name prefix for all resources | string | — | yes |
| instance_type | EC2 instance type | string | t3.micro | no |
| server_port | Port httpd listens on | number | 8080 | no |
| alb_port | Port the ALB listens on | number | 80 | no |
| min_size | Minimum ASG instances | number | — | yes |
| max_size | Maximum ASG instances | number | — | yes |

## Module Outputs

| Name | Description |
|------|-------------|
| alb_dns_name | Paste in browser to test |
| asg_name | ASG name for scaling policies |
| alb_arn | ALB ARN for additional listeners |

## Environment Comparison

| | Dev | Production |
|---|---|---|
| instance_type | t3.micro | t3.small |
| min_size | 2 | 4 |
| max_size | 4 | 10 |

## Notes

- `backend.hcl` is gitignored — use `backend.hcl.example` as template
- `us-east-1e` is excluded — does not support t3.micro/t3.small
- Wait 2-3 minutes after apply for instances to pass health checks
- State files stored under `live/` in the shared S3 bucket