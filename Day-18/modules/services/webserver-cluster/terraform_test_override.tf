

# This file is used during terraform test runs only.
# It overrides the backend configuration so unit tests
# don't need a real S3 bucket to store state.
# terraform test uses an in-memory backend automatically
# when running with command = plan.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # Skip real AWS API calls during unit tests
  # Unit tests use command = plan which doesn't need real credentials
  # for most assertions — but the provider still needs to be configured
}