# -----------------------------
# ENVIRONMENT — drives everything
# -----------------------------

# The validation block catches invalid values at plan time.
# Without it, someone could pass environment = "prod" instead of "production"
# and get a silent misconfiguration — wrong instance type, wrong cluster size.
# With it, Terraform errors immediately with a clear message before anything deploys.
variable "environment" {
  description = "Deployment environment. Controls instance type, cluster size, and monitoring."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "cluster_name" {
  description = "Name prefix for all resources. Must be unique per environment."
  type        = string
}

# -----------------------------
# OPTIONAL FEATURE TOGGLES
# -----------------------------

# These booleans control whether optional resources are created.
# count = var.enable_monitoring ? 1 : 0
# true  → resource created
# false → resource skipped entirely
variable "enable_monitoring" {
  description = "Create CloudWatch alarms and autoscaling policies. Recommended for production."
  type        = bool
  default     = false
}

variable "create_dns_record" {
  description = "Create a Route53 DNS record pointing to the ALB."
  type        = bool
  default     = false
}

variable "use_existing_vpc" {
  description = "Use an existing VPC instead of the default. Set to true for brownfield deployments."
  type        = bool
  default     = false
}

# -----------------------------
# NETWORKING
# -----------------------------

variable "existing_vpc_name" {
  description = "Name tag of the existing VPC to use. Only required when use_existing_vpc = true."
  type        = string
  default     = null
}

variable "server_port" {
  description = "Port httpd listens on inside the EC2 instance."
  type        = number
  default     = 8080
}

variable "alb_port" {
  description = "Port the ALB listens on publicly."
  type        = number
  default     = 80
}

variable "custom_message" {
  description = "Message displayed on the web server home page."
  type        = string
  default     = "Highly Available"
}