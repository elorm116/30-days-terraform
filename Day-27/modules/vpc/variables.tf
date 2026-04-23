variable "vpc_cidr" {
  description = "CIDR block for the VPC. Use non-overlapping ranges across regions to enable future VPC peering."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ. ALB and NAT Gateways live here. Must be within vpc_cidr."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnets (in different AZs) are required for ALB multi-AZ support."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — one per AZ. EC2 instances and RDS live here. No direct internet access."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnets are required for RDS Multi-AZ and ASG distribution."
  }
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets into. Length must match public_subnet_cidrs and private_subnet_cidrs."
  type        = list(string)
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "AWS region identifier — used in resource names to distinguish multi-region deployments"
  type        = string
  # No default — every module call must explicitly state which region it belongs to.
  # Makes resource names self-documenting and prevents confusion in multi-region plans.
}

variable "tags" {
  description = "Additional tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
