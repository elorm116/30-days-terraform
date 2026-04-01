variable "project_id" {
  description = "GCP project ID"
  type        = string
  # Set via TF_VAR_project_id or pass on command line
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "me-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "me-central1-a"
}