locals {
  aws_region    = "us-east-1"
  state_bucket  = "mali-terraform-state-day25"
  project       = "terragrunt-static-site"
  challenge     = "30-day-terraform"
  module_source = "${get_repo_root()}/terragrunt-static-site/modules/s3-static-website"
}

remote_state {
  backend = "s3"

  config = {
    bucket       = local.state_bucket
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Project   = "${local.project}"
      Challenge = "${local.challenge}"
      ManagedBy = "Terragrunt"
    }
  }
}
EOF
}

inputs = {
  index_document = "index.html"
  error_document = "error.html"
  tags = {
    Challenge = local.challenge
    Project   = local.project
  }
}
