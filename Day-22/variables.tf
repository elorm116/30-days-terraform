variable "aws_region" {
  description = "AWS Region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
}

variable "min_size" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number

  validation {
    condition     = var.min_size >= 1
    error_message = "The ASG must have at least 1 instance for high availability."
  }
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number

  validation {
    condition     = var.max_size <= 10
    error_message = "Max size cannot exceed 10 to keep Day 22 costs under control."
  }
}
variable "desired_capacity" {
  description = "The desired number of EC2 Instances in the ASG"
  type        = number
  default     = 2
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

variable "instance_type" {
  description = "The type of EC2 Instances to run"
  type        = string
  default     = "t3.micro"

  validation {
    # This check ensures only approved, cost-effective types are used
    condition     = contains(["t2.micro", "t3.micro", "t3.small"], var.instance_type)
    error_message = "The instance_type must be one of: t2.micro, t3.micro, t3.small."
  }
}

variable "alert_emails" {
  description = "A list of email addresses to send CloudWatch alarms to"
  type        = list(string)
  default     = []
}

variable "cpu_alarm_threshold_high" {
  description = "CPU threshold for ASG scale-out alarm"
  type        = number
  default     = 80
}
