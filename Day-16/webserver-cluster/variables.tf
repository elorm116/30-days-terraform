# -----------------------------
# CORE VARIABLES
# -----------------------------

variable "cluster_name" {
  description = "Name prefix for all resources. Must be unique per environment."
  type        = string

  # Validation ensures cluster_name follows a safe naming convention.
  # AWS resource names can't have spaces or special characters.
  # This regex allows only lowercase letters, numbers, and hyphens.
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "cluster_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment — controls instance sizing, monitoring, and alarm thresholds."
  type        = string

  # Without validation someone could pass environment = "prod" instead
  # of "production" and silently get wrong sizing from the locals block.
  # This catches it at plan time before anything deploys.
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "project_name" {
  description = "Project name — used in tagging for cost allocation and filtering."
  type        = string
  default     = "30-day-terraform"
}

variable "team_name" {
  description = "Team that owns this infrastructure — used in tagging for ownership tracking."
  type        = string
  default     = "devops"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

# -----------------------------
# INSTANCE CONFIGURATION
# -----------------------------

variable "instance_type" {
  description = "EC2 instance type. Must be t2 or t3 family for cost control."
  type        = string
  default     = "t3.micro"

  # This regex validation prevents accidentally deploying expensive
  # instance types like m5.xlarge in a module meant for web servers.
  # can() returns true if the expression doesn't error — used here
  # because regex() throws an error on non-match rather than returning false.
  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be t2 or t3 family (e.g. t3.micro, t2.small)."
  }
}

variable "server_port" {
  description = "Port httpd listens on inside the EC2 instance."
  type        = number
  default     = 8080

  validation {
    condition     = var.server_port > 1024 && var.server_port < 65535
    error_message = "server_port must be between 1024 and 65535 (non-privileged ports only)."
  }
}

variable "alb_port" {
  description = "Port the ALB listens on publicly."
  type        = number
  default     = 80
}

# -----------------------------
# SCALING CONFIGURATION
# -----------------------------

variable "min_size" {
  description = "Minimum number of instances in the ASG."
  type        = number

  # No default — caller must decide capacity explicitly per environment.
  # Forcing this prevents accidentally deploying production with dev sizing.
  validation {
    condition     = var.min_size >= 1
    error_message = "min_size must be at least 1."
  }
}

variable "max_size" {
  description = "Maximum number of instances in the ASG."
  type        = number

  validation {
    condition     = var.max_size >= var.min_size
    error_message = "max_size must be greater than or equal to min_size."
  }
}

# -----------------------------
# OBSERVABILITY
# -----------------------------

variable "enable_monitoring" {
  description = "Create CloudWatch alarms and SNS alerts. Recommended for production."
  type        = bool
  default     = false
}

variable "alarm_email" {
  description = "Email address to receive CloudWatch alarm notifications."
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "CPU percentage that triggers the high CPU alarm."
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_alarm_threshold > 0 && var.cpu_alarm_threshold <= 100
    error_message = "cpu_alarm_threshold must be between 1 and 100."
  }
}

# -----------------------------
# APPLICATION
# -----------------------------

variable "app_version" {
  description = "Application version string — changing this triggers a rolling update."
  type        = string
  default     = "v3"
}