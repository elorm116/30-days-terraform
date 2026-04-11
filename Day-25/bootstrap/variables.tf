variable "state_bucket_name" {
  description = "Name of the S3 bucket to store Terraform state"
  type        = string
  default     = "mali-terraform-state-day25"
}

variable "enable_versioning" {
  description = "Enable versioning on the state bucket for rollback capability"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable server-side encryption on the state bucket"
  type        = bool
  default     = true
}
