variable "region" {
  type    = string
  default = "us-east-1"
}

variable "terraform_day4_bucket" {
  description = "Globally-unique S3 bucket name for Terraform remote state"
  type        = string
}
