# terraform-aws-webserver-cluster

A reusable Terraform module that provisions a highly available
web server cluster behind an Application Load Balancer using
an Auto Scaling Group on AWS.

## Versions

| Version | Description |
|---------|-------------|
| v0.0.1 | Initial stable release |
| v0.0.2 | Added custom_message variable |

## What This Module Creates

- ALB security group (internet → ALB port)
- EC2 security group (ALB only → server port)
- Launch template (Amazon Linux 2023 + httpd)
- Application Load Balancer
- Target group with health checks
- ALB listener with 404 default action
- ALB listener rule (forwards /* to target group)
- Auto Scaling Group with ELB health checks

## Usage

### Minimum required inputs
```hcl
module "webserver_cluster" {
  source = "github.com/elorm116/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name = "webservers-dev"
  min_size     = 2
  max_size     = 4
}

output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
}
```

### Full example
```hcl
module "webserver_cluster" {
  source = "github.com/elorm116/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name   = "webservers-production"
  instance_type  = "t3.small"
  min_size       = 4
  max_size       = 10
  server_port    = 8080
  alb_port       = 80
  custom_message = "Production — Stable"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | Name prefix for all resources | string | — | yes |
| instance_type | EC2 instance type | string | t3.micro | no |
| server_port | Port httpd listens on | number | 8080 | no |
| alb_port | Port the ALB listens on | number | 80 | no |
| min_size | Minimum ASG instances | number | — | yes |
| max_size | Maximum ASG instances | number | — | yes |
| custom_message | Message on web server home page | string | Highly Available | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_dns_name | Paste in browser to test the cluster |
| asg_name | ASG name for scaling policies and alarms |
| alb_arn | ALB ARN for additional listeners or WAF |

## Prerequisites

- Terraform >= 1.10
- AWS credentials configured
- Permissions: EC2, ELB, AutoScaling, VPC

## Known Limitations

- Uses the default VPC — for custom VPC support pass vpc_id
  and subnet_ids as variables (planned for v0.0.3)
- Excludes us-east-1e — does not support t3.micro or t3.small
- HTTP only — no HTTPS listener (planned for v0.0.3)
- Wait 2-3 minutes after apply for instances to pass health checks

## Versioning

Pin to a specific version to avoid unexpected changes:
```hcl
# production — always pin
source = "github.com/elorm116/terraform-aws-webserver-cluster?ref=v0.0.1"

# dev — can test latest
source = "github.com/elorm116/terraform-aws-webserver-cluster?ref=v0.0.2"
```

Never reference without a version in a team environment.