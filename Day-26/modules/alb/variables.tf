variable "name" {
  description = "Name prefix for ALB and related resources"
  type        = string
  # No default — the caller must name the ALB. Generic defaults produce
  # naming collisions when multiple apps are deployed to the same account.
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of public subnet IDs for the ALB. Must span at least two Availability Zones — AWS requires multi-AZ for ALBs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "ALB requires at least two subnets in different Availability Zones."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "health_check_path" {
  description = "HTTP path for ALB target group health checks"
  type        = string
  default     = "/health"
  # Pointing at /health (a dedicated lightweight endpoint) is better than /
  # because it doesn't trigger application logic, caching, or auth redirects.
}

variable "health_check_threshold" {
  description = "Number of consecutive successful health checks before marking an instance healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking an instance unhealthy"
  type        = number
  default     = 3
}

variable "enable_deletion_protection" {
  description = "Prevent the ALB from being accidentally deleted via the AWS Console or CLI. Always true in production."
  type        = bool
  default     = false
  # Default false for dev/staging so terraform destroy works cleanly.
  # The calling configuration sets this to true for production.
}

variable "enable_https" {
  description = "Whether to enable HTTPS listener and open port 443 on the ALB security group"
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener (required if enable_https is true)"
  type        = string
  default     = null

  validation {
    condition     = var.enable_https == false || (var.acm_certificate_arn != null && length(trim(var.acm_certificate_arn)) > 0)
    error_message = "acm_certificate_arn must be set when enable_https is true."
  }
}

variable "high_request_count_threshold" {
  description = "RequestCountPerTarget threshold for the high-traffic CloudWatch alarm"
  type        = number
  default     = 1000
}

variable "tags" {
  description = "Additional tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
