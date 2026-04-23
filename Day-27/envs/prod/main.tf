# envs/prod/main.tf
#
# Production multi-region HA configuration.
# Deploys identical 3-tier stacks in us-east-1 (primary) and us-west-2 (secondary),
# then wires them together with Route53 DNS failover.
#
# Module dependency graph (Terraform infers from value references):
#
#   vpc_primary ──► alb_primary ──► asg_primary ──► rds_primary
#                                                        │
#   vpc_secondary ► alb_secondary ► asg_secondary        │ (ARN)
#                                       │                ▼
#                                       └──────► rds_replica (cross-region)
#
#   alb_primary  ──► route53 ◄── alb_secondary
#

# ── Shared suffix for globally unique names ────────────────────────────────────
resource "random_id" "suffix" {
  byte_length = 4
}

# ═══════════════════════════════════════════════════════════════════════════════
# PRIMARY REGION — us-east-1
# ═══════════════════════════════════════════════════════════════════════════════

module "vpc_primary" {
  source    = "../../modules/vpc"
  providers = { aws = aws.primary }

  vpc_cidr             = var.primary_vpc_cidr
  public_subnet_cidrs  = var.primary_public_subnet_cidrs
  private_subnet_cidrs = var.primary_private_subnet_cidrs
  availability_zones   = var.primary_availability_zones
  environment          = var.environment
  region               = "us-east-1"
  tags                 = local.shared_tags
}

module "alb_primary" {
  source    = "../../modules/alb"
  providers = { aws = aws.primary }

  name        = var.app_name
  vpc_id      = module.vpc_primary.vpc_id
  subnet_ids  = module.vpc_primary.public_subnet_ids
  environment = var.environment
  region      = "us-east-1"
  tags        = local.shared_tags
}

module "asg_primary" {
  source    = "../../modules/asg"
  providers = { aws = aws.primary }

  launch_template_ami   = var.primary_ami_id
  instance_type         = var.instance_type
  vpc_id                = module.vpc_primary.vpc_id
  subnet_ids            = module.vpc_primary.private_subnet_ids
  target_group_arns     = [module.alb_primary.target_group_arn]
  alb_security_group_id = module.alb_primary.alb_security_group_id
  db_secret_arn         = module.rds_primary.db_secret_arn
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.desired_capacity
  environment           = var.environment
  region                = "us-east-1"
  app_name              = var.app_name
  tags                  = local.shared_tags
}

module "rds_primary" {
  source    = "../../modules/rds"
  providers = { aws = aws.primary }

  identifier            = "${var.app_name}-db-primary-${random_id.suffix.hex}"
  db_name               = var.db_name
  db_username           = var.db_username
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  subnet_ids            = module.vpc_primary.private_subnet_ids
  vpc_id                = module.vpc_primary.vpc_id
  app_security_group_id = module.asg_primary.instance_security_group_id
  multi_az              = true
  is_replica            = false
  environment           = var.environment
  region                = "us-east-1"
  tags                  = local.shared_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECONDARY REGION — us-west-2
# ═══════════════════════════════════════════════════════════════════════════════

module "vpc_secondary" {
  source    = "../../modules/vpc"
  providers = { aws = aws.secondary }

  vpc_cidr             = var.secondary_vpc_cidr
  public_subnet_cidrs  = var.secondary_public_subnet_cidrs
  private_subnet_cidrs = var.secondary_private_subnet_cidrs
  availability_zones   = var.secondary_availability_zones
  environment          = var.environment
  region               = "us-west-2"
  tags                 = local.shared_tags
}

module "alb_secondary" {
  source    = "../../modules/alb"
  providers = { aws = aws.secondary }

  name        = var.app_name
  vpc_id      = module.vpc_secondary.vpc_id
  subnet_ids  = module.vpc_secondary.public_subnet_ids
  environment = var.environment
  region      = "us-west-2"
  tags        = local.shared_tags
}

module "asg_secondary" {
  source    = "../../modules/asg"
  providers = { aws = aws.secondary }

  launch_template_ami   = var.secondary_ami_id
  instance_type         = var.instance_type
  vpc_id                = module.vpc_secondary.vpc_id
  subnet_ids            = module.vpc_secondary.private_subnet_ids
  target_group_arns     = [module.alb_secondary.target_group_arn]
  alb_security_group_id = module.alb_secondary.alb_security_group_id
  # The replica has no secret of its own — credentials are inherited from the primary.
  # During normal operation, secondary instances don't connect to the DB.
  # After a regional failover and replica promotion, update this to the promoted secret ARN.
  db_secret_arn         = module.rds_primary.db_secret_arn
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.desired_capacity
  environment           = var.environment
  region                = "us-west-2"
  app_name              = var.app_name
  tags                  = local.shared_tags
}

# ── Cross-Region Read Replica ──────────────────────────────────────────────────
# The most critical cross-region dependency in the entire configuration.
# module.rds_primary.db_instance_arn is the ARN of the primary RDS instance
# in us-east-1. This ARN is passed as replicate_source_db to create an
# asynchronous cross-region read replica in us-west-2.
#
# During a regional failover, the replica must be promoted to a standalone
# primary before it can accept write traffic. This is a manual step (or automated
# via Lambda) — promotion cannot be pre-configured.
module "rds_replica" {
  source    = "../../modules/rds"
  providers = { aws = aws.secondary }

  identifier            = "${var.app_name}-db-replica-${random_id.suffix.hex}"
  is_replica            = true
  replicate_source_db   = module.rds_primary.db_instance_arn  # ← KEY CROSS-REGION WIRE
  instance_class        = var.db_instance_class
  subnet_ids            = module.vpc_secondary.private_subnet_ids
  vpc_id                = module.vpc_secondary.vpc_id
  app_security_group_id = module.asg_secondary.instance_security_group_id
  environment           = var.environment
  region                = "us-west-2"
  tags                  = local.shared_tags

  # These are ignored for replicas (inherited from primary) but required
  # by the variable schema to satisfy Terraform's type checking
  db_name     = ""
  db_username = ""
  db_password = ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# ROUTE53 — DNS FAILOVER 
# ═══════════════════════════════════════════════════════════════════════════════
# Route53 module intentionally disabled.
# DNS is delegated to Cloudflare for this environment due to existing workloads.
# As a result, AWS Route53 failover routing is not used here.
# In a fully AWS-native setup, this module would be enabled to provide
# automatic DNS-based failover between regions.


# module "route53" {
#   source = "../../modules/route53"
#   # Route53 is global — uses the default provider (us-east-1)

#   hosted_zone_id         = var.hosted_zone_id
#   domain_name            = var.domain_name
#   primary_alb_dns_name   = module.alb_primary.alb_dns_name
#   primary_alb_zone_id    = module.alb_primary.alb_zone_id
#   secondary_alb_dns_name = module.alb_secondary.alb_dns_name
#   secondary_alb_zone_id  = module.alb_secondary.alb_zone_id
#   primary_region         = "us-east-1"
#   secondary_region       = "us-west-2"
#   tags                   = local.shared_tags
# }

# ═══════════════════════════════════════════════════════════════════════════════
# BONUS — S3 CROSS-REGION REPLICATION
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_s3_bucket" "primary_assets" {
  provider = aws.primary
  bucket   = "${var.app_name}-assets-primary-${random_id.suffix.hex}"
  tags     = merge(local.shared_tags, { Region = "us-east-1", Role = "primary" })
}

resource "aws_s3_bucket" "secondary_assets" {
  provider = aws.secondary
  bucket   = "${var.app_name}-assets-secondary-${random_id.suffix.hex}"
  tags     = merge(local.shared_tags, { Region = "us-west-2", Role = "replica" })
}

resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary_assets.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_assets.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  provider                = aws.primary
  bucket                  = aws_s3_bucket.primary_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "secondary" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.secondary_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "s3_replication" {
  provider = aws.primary
  name     = "s3-replication-role-${var.environment}-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.shared_tags
}

resource "aws_iam_role_policy" "s3_replication" {
  provider = aws.primary
  name     = "s3-replication-policy"
  role     = aws_iam_role.s3_replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = aws_s3_bucket.primary_assets.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = "${aws_s3_bucket.primary_assets.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = "${aws_s3_bucket.secondary_assets.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "assets" {
  provider = aws.primary
  role     = aws_iam_role.s3_replication.arn
  bucket   = aws_s3_bucket.primary_assets.id

  rule {
    id     = "replicate-all-objects"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.secondary_assets.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.secondary]
}

# ── Shared local values ────────────────────────────────────────────────────────
locals {
  shared_tags = {
    Owner      = "terraform-challenge"
    Day        = "27"
    CostCentre = "prod-infrastructure"
  }
}
