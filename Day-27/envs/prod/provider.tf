terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# ── Primary Region ─────────────────────────────────────────────────────────────
provider "aws" {
  alias  = "primary"
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "multi-region-ha"
      Day       = "27"
    }
  }
}

# ── Secondary Region ───────────────────────────────────────────────────────────
provider "aws" {
  alias  = "secondary"
  region = "us-west-2"

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "multi-region-ha"
      Day       = "27"
    }
  }
}

# ── Route53 (global — no region alias needed) ──────────────────────────────────
# Route53 resources (health checks, DNS records) are global.
# The route53 module uses the default provider configured here.
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "multi-region-ha"
      Day       = "27"
    }
  }
}
