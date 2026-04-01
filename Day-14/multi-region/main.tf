# -----------------------------
# PROVIDERS
# -----------------------------

# Default provider — no alias needed.
# Any resource that doesn't specify a provider
# automatically uses this one → deploys in us-east-1.
provider "aws" {
  region = var.primary_region
}

# Aliased provider — must be explicitly referenced.
# Resources that need to deploy in us-west-2 must
# specify provider = aws.us_west explicitly.
# Without that explicit reference they'd deploy in us-east-1.
provider "aws" {
  alias  = "us_west"
  region = var.replica_region
}

# -----------------------------
# PRIMARY BUCKET — us-east-1
# -----------------------------

# No provider argument — uses default provider → us-east-1
resource "aws_s3_bucket" "primary" {
  bucket = var.primary_bucket_name
  force_destroy = true # Automatically delete all objects when bucket is destroyed (for demo purposes only)

  tags = {
    Name   = "primary-bucket"
    Region = var.primary_region
  }
}

# Versioning must be enabled on both buckets for replication to work.
# S3 replication tracks object versions — without versioning
# it has no way to identify which version of an object to replicate.
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access on primary bucket.
# Replication works between private buckets — no public access needed.
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# REPLICA BUCKET — us-west-2
# -----------------------------

# provider = aws.us_west → Terraform uses the aliased provider
# which points to us-west-2. Without this line this bucket
# would be created in us-east-1 alongside the primary.
resource "aws_s3_bucket" "replica" {
  provider = aws.us_west
  bucket   = var.replica_bucket_name
  force_destroy = true # Automatically delete all objects when bucket is destroyed (for demo purposes only)
  tags = {
    Name   = "replica-bucket"
    Region = var.replica_region
  }
}

# Versioning on replica bucket — also required for replication destination.
resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.us_west
  bucket   = aws_s3_bucket.replica.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access on replica bucket.
resource "aws_s3_bucket_public_access_block" "replica" {
  provider                = aws.us_west
  bucket                  = aws_s3_bucket.replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# IAM ROLE — S3 REPLICATION
# -----------------------------

# S3 replication doesn't happen by magic — AWS needs permission
# to read from the primary bucket and write to the replica bucket.
# This IAM role grants S3 the ability to assume it and perform
# replication on your behalf.
#
# Think of it as: "S3 service is allowed to act as this role
# and use the permissions attached to it."
resource "aws_iam_role" "replication" {
  name = "day14-s3-replication-role"

  # Trust policy — who can assume this role
  # s3.amazonaws.com = the S3 service itself
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "day14-s3-replication-role"
  }
}

# Permission policy — what the role can do
# The S3 service needs to:
# - Read objects from the primary bucket
# - Read object versions from the primary bucket
# - Write objects to the replica bucket
# - Read replica configuration
resource "aws_iam_role_policy" "replication" {
  name = "day14-s3-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Read permissions on primary bucket
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        # Read object versions from primary bucket
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        # Write permissions on replica bucket
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.replica.arn}/*"
      }
    ]
  })
}

# -----------------------------
# REPLICATION CONFIGURATION
# -----------------------------

# This tells the primary bucket to replicate its objects
# to the replica bucket using the IAM role we created.
# It depends on versioning being enabled — hence depends_on.
resource "aws_s3_bucket_replication_configuration" "replication" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all-objects"
    status = "Enabled"

    # No filter = replicate ALL objects in the bucket.
    # You can add a filter block to replicate only specific
    # prefixes or tags if needed.
    filter {}

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }

    # Delete markers control what happens when you delete
    # an object in the primary bucket.
    # Enabled = deletions are also replicated to the replica.
    delete_marker_replication {
      status = "Enabled"
    }
  }

  # Replication requires versioning to be enabled first.
  # depends_on ensures versioning is configured before
  # Terraform tries to set up replication.
  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.replica
  ]
}