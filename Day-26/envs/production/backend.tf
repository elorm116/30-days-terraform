terraform {
  backend "s3" {
    bucket       = "dark-knight-terraform-state"
    key          = "day26/production/webserver-cluster/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

    # Keep credentials out of code; use env vars or SSO/OIDC.
  }
}
