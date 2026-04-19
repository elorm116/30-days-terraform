variable "app_name" {
  description = "Application name — used as a prefix in all resource names"
  type        = string
  default     = "web-challenge-day26"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. Amazon Linux 2023 recommended. Must match the deployment region."
  type        = string
  # us-east-1: ami-0c02fb55956c7d316 (Amazon Linux 2023)
  # us-west-2: ami-0ceecbb0f30a902a6 (Amazon Linux 2023)
  # eu-west-1: ami-0d71ea30463e0ff49 (Amazon Linux 2023)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access. Set to null to disable SSH (recommended for dev)."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID. Leave empty to use the default VPC."
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB and ASG (dev uses public subnets for simplicity). Leave empty to auto-discover from the VPC."
  type        = list(string)
  default     = []
}

variable "excluded_availability_zones" {
  description = "Availability Zones to exclude when auto-discovering subnets (useful when some instance types are not supported in specific AZs)."
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (used in production for instance isolation). Unused in dev."
  type        = list(string)
  default     = []
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Initial desired number of ASG instances"
  type        = number
  default     = 2
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
  default     = 1000
}
