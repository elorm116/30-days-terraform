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
}

resource "aws_s3_bucket" "state" {
  bucket = "dark-knight-terraform-state"
}