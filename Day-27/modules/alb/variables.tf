variable "name" {
  description = "Name prefix for ALB and related resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of PUBLIC subnet IDs for the ALB — must span at least two AZs"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "ALB requires at least two subnets in different Availability Zones."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "AWS region — embedded in resource names for multi-region clarity"
  type        = string
}

variable "health_check_path" {
  description = "HTTP path for target group health checks"
  type        = string
  default     = "/health"
}

variable "deregistration_delay" {
  description = "Seconds the ALB waits before stopping traffic to a deregistered target"
  type        = number
  default     = 30
  # Reduced from AWS default (300s) for faster rolling deploys in prod.
  # Allows in-flight requests to complete before the instance is removed.
}

variable "enable_deletion_protection" {
  description = "Prevent accidental deletion via the AWS Console. Always true in production."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
