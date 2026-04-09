# Pass-through variables for the webserver-cluster module

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name prefix for all resources in the production cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, test, staging, or prod."
  }
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "project_name" {
  description = "Project name for cost allocation and tagging"
  type        = string
  default     = "30-day-terraform"
}

variable "team_name" {
  description = "Team that owns this infrastructure"
  type        = string
  default     = "devops"
}

variable "server_port" {
  description = "Port the web server listens on"
  type        = number
  default     = 8080
}

variable "alb_port" {
  description = "Port the ALB listens on"
  type        = number
  default     = 80
}

variable "custom_message" {
  description = "Custom message displayed on the web server"
  type        = string
  default     = "Highly Available"
}

variable "enable_destroy_protection" {
  description = "Enable destroy protection to prevent accidental teardown"
  type        = bool
  default     = false
}

variable "app_version" {
  description = "Application version to display"
  type        = string
  default     = "v1.0.0"
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = false
}

variable "alarm_email" {
  description = "Email for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "CPU threshold percentage for alarms"
  type        = number
  default     = 80
}
