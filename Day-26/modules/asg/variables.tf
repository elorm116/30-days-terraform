variable "launch_template_id" {
  description = "ID of the EC2 Launch Template. Comes from module.ec2.launch_template_id."
  type        = string
}

variable "launch_template_version" {
  description = "Version of the Launch Template to use. Defaults to $Latest so instances always use the newest template version. Set to a specific version number to pin."
  type        = string
  default     = "$Latest"
}

variable "subnet_ids" {
  description = "List of subnet IDs where ASG instances will launch. Use private subnets — instances should not be directly accessible from the internet; the ALB handles public traffic."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 1
    error_message = "At least one subnet ID is required for the ASG."
  }
}

variable "target_group_arns" {
  description = "List of ALB target group ARNs to attach to the ASG. Comes from module.alb.target_group_arn. This is the connection that registers instances with the load balancer."
  type        = list(string)
}

variable "min_size" {
  description = "Minimum number of EC2 instances. Must be >= 1 to maintain availability."
  type        = number
  default     = 1

  validation {
    condition     = var.min_size >= 1
    error_message = "min_size must be >= 1. Setting to 0 means the service can go completely offline."
  }
}

variable "max_size" {
  description = "Maximum number of EC2 instances. Caps the cost ceiling for auto scaling."
  type        = number
  default     = 4

  validation {
    condition     = var.max_size >= var.min_size
    error_message = "max_size must be >= min_size."
  }
}

variable "desired_capacity" {
  description = "Initial desired number of instances. After first apply, ASG manages this dynamically based on scaling policies."
  type        = number
  default     = 2
}

variable "cpu_scale_out_threshold" {
  description = "Average CPU utilisation (%) at which to add one instance. Evaluated over 2 × 120-second periods."
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_scale_out_threshold > 0 && var.cpu_scale_out_threshold <= 100
    error_message = "cpu_scale_out_threshold must be between 1 and 100."
  }
}

variable "cpu_scale_in_threshold" {
  description = "Average CPU utilisation (%) at which to remove one instance. Must be lower than scale-out threshold."
  type        = number
  default     = 30

  validation {
    condition     = var.cpu_scale_in_threshold > 0 && var.cpu_scale_in_threshold < 100
    error_message = "cpu_scale_in_threshold must be between 1 and 99."
  }
}

variable "scale_out_cooldown" {
  description = "Seconds to wait after a scale-out event before another scaling activity can start. Prevents over-scaling."
  type        = number
  default     = 300
}

variable "scale_in_cooldown" {
  description = "Seconds to wait after a scale-in event before another scaling activity can start. Longer than scale-out to prevent thrashing."
  type        = number
  default     = 600
}

variable "health_check_grace_period" {
  description = "Seconds the ASG waits after launching an instance before starting health checks. Must be long enough for the user data bootstrap to complete."
  type        = number
  default     = 300
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "app_name" {
  description = "Application name — used in resource names and tags"
  type        = string
  default     = "web"
}

variable "force_delete" {
  description = "Allow the ASG to be deleted without waiting for instances to drain. Safe in dev; never use in production."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
}
