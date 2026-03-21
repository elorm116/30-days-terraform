variable "region" {
  type = string
  default = "us-east-1"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type = string
  default = "t3.micro"
}

variable "server_port" {
  description = "Port for the web server"
  type = number
  default = 80
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 5
}