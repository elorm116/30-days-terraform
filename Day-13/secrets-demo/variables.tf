variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# -----------------------------
# SENSITIVE VARIABLES
# -----------------------------

# sensitive = true does TWO things:
# 1. Terraform shows (sensitive value) in plan/apply output
#    instead of the actual value
# 2. Prevents the value from appearing in logs or CI/CD output
#
# It does NOT prevent the value from being stored in state.
# The state file still contains the plaintext value.
# That's why encrypting and restricting access to the state
# bucket is non-negotiable.
#
# No default value — secrets must NEVER have defaults.
# If you set default = "my-password" it gets committed to Git.
# Without a default Terraform prompts for it or reads from
# TF_VAR_db_password environment variable.
variable "db_password" {
  description = "Database administrator password — injected via TF_VAR_db_password or prompted"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}