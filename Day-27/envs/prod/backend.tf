terraform {
  backend "s3" {
    bucket         = "dark-knight-terraform-state"
    key            = "day27/multi-region-ha/prod/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
