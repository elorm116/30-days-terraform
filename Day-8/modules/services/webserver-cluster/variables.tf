variable "cluster_name" {
  description = "Used to name all resources in this module. Must be unique per environment to avoid clashes when dev and production run simultaneously in the same AWS account."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the web servers. Kept as a variable so dev can use t3.micro and production can use something larger without changing the module."
  type        = string
  default     = "t3.micro"
}

variable "server_port" {
  description = "Port httpd listens on inside the EC2 instance. ALB forwards traffic here. Default is 8080 so port 80 stays free for the ALB listener."
  type        = number
  default     = 8080
}

variable "alb_port" {
  description = "Port the ALB listens on publicly. Always 80 for HTTP. Kept as a variable in case you want to run the ALB on a non-standard port in testing."
  type        = number
  default     = 80
}

variable "min_size" {
  description = "Minimum number of EC2 instances the ASG will maintain. No default — caller must decide this per environment. Dev and production have very different availability requirements."
  type        = number
}

variable "max_size" {
  description = "Maximum number of EC2 instances the ASG can scale to. No default — caller must decide this per environment based on expected load."
  type        = number
}