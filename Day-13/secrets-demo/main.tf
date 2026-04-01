provider "aws" {
  region = var.region
}

# -----------------------------
# DATA SOURCES — SECRETS MANAGER
# -----------------------------

# This is the secure pattern for consuming secrets.
# The secret was created manually via AWS CLI — it never
# touched a .tf file or got committed to Git.
#
# At apply time Terraform fetches the secret from Secrets Manager.
# The value exists in memory during the apply but never in your code.
# The only risk is the state file — which is why we encrypt it.
data "aws_secretsmanager_secret" "db_credentials" {
  name = "day13/db/credentials"
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = data.aws_secretsmanager_secret.db_credentials.id
}

# jsondecode parses the JSON secret string into a map
# so we can reference individual fields by key
locals {
  db_credentials = jsondecode(
    data.aws_secretsmanager_secret_version.db_credentials.secret_string
  )
}

# -----------------------------
# NETWORKING — RDS needs a subnet group
# -----------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# RDS requires a DB subnet group — a collection of subnets
# across at least 2 AZs where the DB instance can be placed
resource "aws_db_subnet_group" "main" {
  name       = "day13-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "day13-db-subnet-group"
  }
}

# -----------------------------
# SECURITY GROUP — RDS
# -----------------------------

# Only allow MySQL traffic (3306) from within the VPC
# Never expose RDS directly to the internet
resource "aws_security_group" "rds_sg" {
  name   = "day13-rds-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "day13-rds-sg"
  }
}

# -----------------------------
# RDS INSTANCE
# -----------------------------

# This is the key demonstration:
# username and password come from Secrets Manager via locals
# They are NEVER hardcoded in this file
# They are NEVER in a variable with a default value
# They are fetched at runtime from Secrets Manager
#
# The state file will still contain these values in plaintext
# after apply — that's unavoidable for RDS credentials.
# The protection is: encrypted S3 bucket + restricted IAM access.
resource "aws_db_instance" "main" {
  identifier        = "day13-demo-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 10
  db_name           = "appdb"

  # Credentials fetched from Secrets Manager at runtime
  # These values are sensitive — they will be masked in plan output
  username = local.db_credentials["username"]
  password = local.db_credentials["password"]

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # skip_final_snapshot = true for demo purposes
  # In production always set this to false and name the snapshot
  skip_final_snapshot = true

  # Encrypt the database storage at rest
  storage_encrypted = true

  tags = {
    Name = "day13-demo-db"
  }
}