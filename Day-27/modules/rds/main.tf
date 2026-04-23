terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }
  }
}

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "multi-region-ha"
    Region      = var.region
    Role        = var.is_replica ? "read-replica" : "primary"
  })
}

# ── RDS Security Group ─────────────────────────────────────────────────────────
# Only accepts MySQL connections from the application security group.
# The database is never directly internet-accessible.
resource "aws_security_group" "rds" {
  name        = "rds-sg-${var.environment}-${var.region}"
  description = "Allow MySQL 3306 from app tier SG only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from app tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "rds-sg-${var.environment}-${var.region}" })
}

# ── DB Subnet Group ────────────────────────────────────────────────────────────
# Groups private subnets across AZs so RDS can place the primary and standby
# in different AZs for Multi-AZ deployments.
resource "aws_db_subnet_group" "main" {
  name       = "db-subnet-group-${var.environment}-${var.region}"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, { Name = "db-subnet-group-${var.environment}-${var.region}" })
}

resource "random_password" "db_master" {
  count   = var.is_replica ? 0 : 1
  length  = 24
  special = true
}

resource "aws_secretsmanager_secret" "db_master" {
  count       = var.is_replica ? 0 : 1
  name        = "${var.identifier}-master-credentials"
  description = "Master credentials for ${var.identifier}"

  tags = merge(local.common_tags, { Name = "${var.identifier}-master-credentials" })
}

resource "aws_secretsmanager_secret_version" "db_master" {
  count = var.is_replica ? 0 : 1

  secret_id = aws_secretsmanager_secret.db_master[0].id
  secret_string_wo = jsonencode({
    username = var.db_username
    password = random_password.db_master[0].result
  })
  secret_string_wo_version = 1
}

data "aws_kms_alias" "rds" {
  name = "alias/aws/rds"
}

# ── RDS Instance (Primary or Read Replica) ─────────────────────────────────────
# This single resource handles both cases:
#   is_replica = false → creates a Multi-AZ primary instance
#   is_replica = true  → creates a cross-region read replica from replicate_source_db
#
# The conditional nulls (engine_version = var.is_replica ? null : var.engine_version)
# are required because AWS rejects replica creation requests that specify engine
# attributes — replicas inherit those from the primary automatically.
resource "aws_db_instance" "main" {
  identifier     = var.identifier
  instance_class = var.instance_class


  # Engine configuration — only set for primary, inherited from source for replicas
  engine         = var.is_replica ? null : "mysql"
  engine_version = var.is_replica ? null : var.engine_version

  # Storage — only set for primary
  allocated_storage = var.is_replica ? null : var.allocated_storage

  # Credentials — only set for primary (replica inherits from source)
  # The primary uses a generated password stored in a separate Secrets Manager
  # secret so replicas can still be created from the source instance.
  db_name  = var.is_replica ? null : (var.db_name != "" ? var.db_name : null)
  username = var.is_replica ? null : (var.db_username != "" ? var.db_username : null)

  password_wo         = var.is_replica ? null : random_password.db_master[0].result
  password_wo_version = var.is_replica ? null : 1

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # HA configuration
  # Multi-AZ: RDS automatically creates a standby replica in a different AZ.
  # Failover is automatic (60-120 seconds) — RDS promotes the standby if the
  # primary fails. This protects against AZ-level failures, NOT region failures.
  multi_az = var.is_replica ? false : var.multi_az

  # Cross-region read replica
  # replicate_source_db is the full ARN of the primary instance.
  # This replicates all databases asynchronously across regions.
  # Read replicas can be promoted to standalone primaries during a regional outage.
  replicate_source_db = var.is_replica ? var.replicate_source_db : null
  kms_key_id          = var.is_replica ? coalesce(var.kms_key_id, data.aws_kms_alias.rds.target_key_arn) : null

  # Backup
  # Forced to 1 for Free Tier compatibility. 
  # Replicas must be 0.
  backup_retention_period = var.is_replica ? 0 : 1

  # Security
  storage_encrypted = true

  # Lifecycle
  skip_final_snapshot = true  # Required for clean terraform destroy
  deletion_protection = !var.is_replica && var.environment == "prod" ? true : false

  tags = merge(local.common_tags, { Name = var.identifier })

  # Replicas depend on the primary being in a state that allows replication.
  # Terraform infers this from the replicate_source_db ARN reference, but
  # depends_on makes the intent explicit.
  lifecycle {
    ignore_changes = []
  }
}

# ── RDS Enhanced Monitoring ────────────────────────────────────────────────────
# Provides OS-level metrics (CPU steal, memory usage) not available in basic monitoring.
resource "aws_iam_role" "rds_monitoring" {
  count = var.is_replica ? 0 : 1
  name  = "rds-monitoring-role-${var.environment}-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_attach" {
  # This only creates the attachment if the role was created
  count      = var.is_replica ? 0 : 1
  
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
