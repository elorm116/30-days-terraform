variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials. Granted to the instance IAM role so user_data can fetch it at boot."
  type        = string
}

variable "launch_template_ami" {
  description = "AMI ID for EC2 instances. Must be region-specific — AMI IDs do not transfer across regions."
  type        = string
  # No default — AMIs are region-specific. Forcing the caller to supply this
  # prevents accidentally booting the wrong image in the wrong region.
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "Private subnet IDs where instances will launch. Private subnets have no direct internet access — outbound traffic goes via NAT Gateway."
  type        = list(string)
}

variable "target_group_arns" {
  description = "ALB target group ARNs. Instances automatically register here on launch and deregister on termination."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB. The instance SG only allows inbound on port 80 from this SG — instances are not internet-accessible."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the instance security group"
  type        = string
}

variable "min_size" {
  description = "Minimum ASG instance count"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum ASG instance count — cost ceiling"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Initial desired instance count. Managed dynamically by scaling policies after first apply."
  type        = number
  default     = 2
}

variable "cpu_scale_out_threshold" {
  description = "Average CPU % at which to add one instance"
  type        = number
  default     = 70
}

variable "cpu_scale_in_threshold" {
  description = "Average CPU % at which to remove one instance"
  type        = number
  default     = 30
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "AWS region — embedded in resource names for multi-region clarity"
  type        = string
}

variable "app_name" {
  description = "Application name prefix"
  type        = string
  default     = "web"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
