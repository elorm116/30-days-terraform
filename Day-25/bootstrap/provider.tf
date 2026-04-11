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
  region = "us-east-1"

  default_tags {
    tags = {
      Purpose = "Terraform State Backend"
      Project = "30-day-terraform-challenge"
    }
  }
}
