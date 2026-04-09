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
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
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
