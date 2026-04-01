# -----------------------------
# CORE VARIABLES
# -----------------------------

variable "cluster_name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "webservers-day12"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "server_port" {
  description = "Port httpd listens on inside EC2 instances."
  type        = number
  default     = 8080
}

variable "alb_port" {
  description = "Port the ALB listens on publicly."
  type        = number
  default     = 80
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances in the ASG."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in the ASG."
  type        = number
  default     = 4
}

# -----------------------------
# ZERO-DOWNTIME VARIABLES
# -----------------------------

# This is the version string that appears in the HTML response.
# Changing it from "v1" to "v2" triggers a new launch template
# which triggers create_before_destroy on the ASG.
# This is how we simulate an application update.
variable "app_version" {
  description = "Application version — changing this triggers a zero-downtime deployment."
  type        = string
  default     = "v1"
}

# -----------------------------
# BLUE/GREEN VARIABLES
# -----------------------------

# Controls which target group the ALB listener rule forwards to.
# "blue"  → traffic goes to blue target group (current stable)
# "green" → traffic goes to green target group (new version)
# Changing this and running terraform apply shifts traffic instantly.
variable "active_environment" {
  description = "Which environment receives live traffic: blue or green."
  type        = string
  default     = "blue"

  validation {
    condition     = contains(["blue", "green"], var.active_environment)
    error_message = "active_environment must be blue or green."
  }
}