variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type_by_workspace" {
  description = "EC2 instance type per workspace/environment"
  type        = map(string)
  default = {
    dev        = "t3.micro"
    staging    = "t3.micro"
    production = "t3.micro"
  }
}
