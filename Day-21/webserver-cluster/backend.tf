terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }

  cloud {
    organization = "cradx"

    workspaces {
      name = "webserver-cluster-dev"
    }
  }
}

provider "aws" {
  region = var.region
}
