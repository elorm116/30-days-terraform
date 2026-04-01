# -----------------------------
# PROVIDERS — defined in the ROOT, not in the module
# -----------------------------

# The root module owns all provider configurations.
# Modules receive providers from their callers — they
# never define their own. This keeps the caller in control
# of which account and region resources deploy to.
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "replica"
  region = "us-west-2"
}

# -----------------------------
# MODULE CALL
# -----------------------------

# The providers map wires the root module's provider aliases
# to the module's expected aliases:
#
# aws.primary (root) → aws.primary (module)
# aws.replica (root) → aws.replica (module)
#
# The module receives these and uses them internally.
# The root module decides the regions — the module just
# uses whatever it receives.
module "multi_region_s3" {
  source = "../modules/multi-region-s3"

  app_name    = "dark-knight-day15"
  environment = "dev"

  providers = {
    aws.primary = aws.primary
    aws.replica = aws.replica
  }
}

# -----------------------------
# OUTPUTS — surface module outputs
# -----------------------------

output "primary_bucket_name" {
  value = module.multi_region_s3.primary_bucket_name
}

output "primary_bucket_region" {
  value = module.multi_region_s3.primary_bucket_region
}

output "replica_bucket_name" {
  value = module.multi_region_s3.replica_bucket_name
}

output "replica_bucket_region" {
  value = module.multi_region_s3.replica_bucket_region
}