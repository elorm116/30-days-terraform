# webserver-cluster module

Provisions a highly available web server cluster behind an
Application Load Balancer using an Auto Scaling Group.

## What this module creates

- ALB security group (public internet → port 80)
- EC2 security group (ALB only → port 8080)
- Launch template (Amazon Linux 2023 + httpd)
- Application Load Balancer
- Target group with health checks
- ALB listener + forwarding rule
- Auto Scaling Group

## Usage
```hcl
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
}

output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
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

## Outputs

| Name | Description |
|------|-------------|
| alb_dns_name | Paste in browser to test |
| asg_name | ASG name for policies/alarms |
| alb_arn | ALB ARN for additional listeners |

## Notes

- Excludes us-east-1e — does not support t3.micro
- httpd is configured to listen on server_port not 80
- health_check_grace_period is 300s — wait 2-3 mins after apply
```
```

---

## Step 3 — Build the calling configurations

### `live/dev/services/webserver-cluster/backend.tf`
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}
```

### `live/dev/services/webserver-cluster/backend.hcl`
```hcl
bucket       = "dark-knight-terraform-state"
key          = "live/dev/services/webserver-cluster/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

### `live/dev/services/webserver-cluster/main.tf`
```hcl
# This is the dev calling configuration.
# It calls the webserver-cluster module and passes dev-appropriate values.
# Notice there are no resource definitions here — just a module call.
# All the infrastructure logic lives inside the module.

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
}

# Surface the ALB DNS name after apply so you can test immediately
output "alb_dns_name" {
  description = "Dev cluster URL"
  value       = module.webserver_cluster.alb_dns_name
}
```

### `live/production/services/webserver-cluster/backend.tf`

Same as dev `backend.tf` — copy it:
```bash
cp live/dev/services/webserver-cluster/backend.tf \
   live/production/services/webserver-cluster/backend.tf
```

### `live/production/services/webserver-cluster/backend.hcl`
```hcl
bucket       = "dark-knight-terraform-state"
key          = "live/production/services/webserver-cluster/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

### `live/production/services/webserver-cluster/main.tf`
```hcl
# This is the production calling configuration.
# Same module, completely different inputs.
# Larger instances, higher min/max capacity.
# Zero code duplication with dev.

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name  = "webservers-production"
  instance_type = "t3.small"
  min_size      = 4
  max_size      = 10
}

output "alb_dns_name" {
  description = "Production cluster URL"
  value       = module.webserver_cluster.alb_dns_name
}
```

---

## Step 4 — Deploy dev
```bash
cd live/dev/services/webserver-cluster
terraform init -backend-config=backend.hcl
terraform apply
```

`terraform init` does something new here — it sees the `module` block with a local `source` path and **copies the module files into `.terraform/modules/`**. That's why you always run `terraform init` after adding a new module source.

Paste the output and we'll verify it's working before touching production.