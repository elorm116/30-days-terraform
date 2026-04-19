variable "instance_type" {
  description = "EC2 instance type for web server instances"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t3.large"], var.instance_type)
    error_message = "instance_type must be a t3 family type (micro/small/medium/large)."
  }
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. Recommended: Amazon Linux 2023 (region-specific)"
  type        = string
  # No default — AMI IDs are region-specific and change over time.
  # Require the caller to pass the correct AMI for their region.
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Set to null in dev if SSH access is not needed."
  type        = string
  default     = null
  # Nullable — SSH access is optional. Omitting it reduces attack surface.
}

variable "server_port" {
  description = "Port the web server listens on"
  type        = number
  default     = 80

  validation {
    condition     = var.server_port > 1024 || var.server_port == 80 || var.server_port == 443
    error_message = "server_port must be 80, 443, or a port above 1024."
  }
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
  # No default — VPC IDs are account/region specific.
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB. Instances only accept traffic from the ALB, not from the internet directly."
  type        = string
  # No default — this comes from the ALB module output. Passing it here enforces
  # the security boundary: instances are not directly internet-accessible.
}

variable "environment" {
  description = "Deployment environment name"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "app_name" {
  description = "Application name — used as a prefix in resource names"
  type        = string
  default     = "web"
}

variable "tags" {
  description = "Additional tags to apply to all resources in this module"
  type        = map(string)
  default     = {}
  # Optional — callers may add owner, cost-centre, or ticket tags without
  # modifying the module itself.
}
