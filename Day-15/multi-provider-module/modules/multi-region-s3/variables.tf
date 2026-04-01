variable "app_name" {
  description = "Name prefix for all S3 buckets"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}