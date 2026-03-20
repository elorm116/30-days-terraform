variable "region" {
  type = string
  default = "us-east-1"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type = string
  default = "t3.micro"
}

variable "cidr_block" {
  description = "CIDR Block for Security Group"
  type = string
  default = "0.0.0.0/0"
}

variable "server_port" {
  description = "Port for the web server"
  type = number
  default = 80
}