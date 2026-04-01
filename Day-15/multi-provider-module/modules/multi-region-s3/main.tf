# -----------------------------
# PROVIDER DECLARATION
# -----------------------------

# This is the key pattern for multi-provider modules.
# The module does NOT define provider blocks — it declares
# which provider aliases it EXPECTS to receive from the caller.
#
# configuration_aliases tells Terraform:
# "This module requires two AWS provider configurations —
#  one aliased as aws.primary and one aliased as aws.replica.
#  The caller must pass both in the providers map."
#
# Without configuration_aliases Terraform has no way to know
# the module needs multiple provider configurations and will
# error when you try to pass providers into it.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.37"
      configuration_aliases = [aws.primary, aws.replica]
    }
  }
}

# -----------------------------
# PRIMARY BUCKET
# -----------------------------

# provider = aws.primary → uses whatever region the caller
# configured for aws.primary. The module doesn't know or care
# which region that is — the caller decides.
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.app_name}-primary-${var.environment}"

  tags = {
    Name        = "${var.app_name}-primary"
    Environment = var.environment
    Role        = "primary"
  }
}

resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  provider                = aws.primary
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# REPLICA BUCKET
# -----------------------------

# provider = aws.replica → uses whatever region the caller
# configured for aws.replica. Same module, different provider.
resource "aws_s3_bucket" "replica" {
  provider = aws.replica
  bucket   = "${var.app_name}-replica-${var.environment}"

  tags = {
    Name        = "${var.app_name}-replica"
    Environment = var.environment
    Role        = "replica"
  }
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider                = aws.replica
  bucket                  = aws_s3_bucket.replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# OUTPUTS
# -----------------------------

output "primary_bucket_name" {
  description = "Primary bucket name"
  value       = aws_s3_bucket.primary.id
}

output "primary_bucket_region" {
  description = "Primary bucket region"
  value       = aws_s3_bucket.primary.region
}

output "replica_bucket_name" {
  description = "Replica bucket name"
  value       = aws_s3_bucket.replica.id
}

output "replica_bucket_region" {
  description = "Replica bucket region"
  value       = aws_s3_bucket.replica.region
}