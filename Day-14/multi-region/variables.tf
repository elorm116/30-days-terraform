variable "primary_region" {
  description = "Primary AWS region — where the source S3 bucket lives"
  type        = string
  default     = "us-east-1"
}

variable "replica_region" {
  description = "Replica AWS region — where the destination S3 bucket lives"
  type        = string
  default     = "us-west-2"
}

variable "primary_bucket_name" {
  description = "Name of the primary S3 bucket in us-east-1"
  type        = string
  default     = "dark-knight-primary-day14"
}

variable "replica_bucket_name" {
  description = "Name of the replica S3 bucket in us-west-2"
  type        = string
  default     = "dark-knight-replica-day14"
}