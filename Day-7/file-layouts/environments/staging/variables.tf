variable "region" {
  description = "AWS Region"
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for dev"
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Environment Name"
  type    = string
  default = "staging"
}
