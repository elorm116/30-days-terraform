variable "app_name" {
  description = "Application name - used as a prefix in all resource names"
  type        = string
  default     = "web-challenge-day26"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"

  validation {
    condition     = var.environment == "production"
    error_message = "This environment root is intended for production only (environment must be 'production')."
  }
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (region-specific). Prefer an AMI you control (golden image) in production."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Prefer SSM Session Manager and set this to null in production."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID (required in production)"
  type        = string

  validation {
    condition     = length(trimspace(var.vpc_id)) > 0
    error_message = "vpc_id is required in production."
  }
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB (required in production)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "public_subnet_ids must include at least two subnets (multi-AZ ALB requirement)."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ASG instances (required in production)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "private_subnet_ids must include at least two subnets for HA in production."
  }
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the ASG"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Initial desired number of ASG instances"
  type        = number
  default     = 3
}

variable "cpu_scale_out_threshold" {
  description = "CPU % above which the ASG adds an instance"
  type        = number
  default     = 70
}

variable "cpu_scale_in_threshold" {
  description = "CPU % below which the ASG removes an instance"
  type        = number
  default     = 30
}

variable "high_request_count_threshold" {
  description = "Requests per target per minute above which the high-request ALB alarm fires"
  type        = number
  default     = 2000
}
