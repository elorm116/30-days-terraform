terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }
}

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "multi-region-ha"
    Region      = var.region
  })
}

# ── VPC ───────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true   # required for RDS endpoint resolution
  enable_dns_hostnames = true   # required for RDS endpoint resolution

  tags = merge(local.common_tags, { Name = "vpc-${var.environment}-${var.region}" })
}

# ── Internet Gateway ───────────────────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "igw-${var.environment}-${var.region}" })
}

# ── Public Subnets ─────────────────────────────────────────────────────────────
# ALB and NAT Gateways live in public subnets.
# map_public_ip_on_launch = true so NAT Gateway EIPs are reachable.
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "public-subnet-${count.index + 1}-${var.region}"
    Tier = "public"
  })
}

# ── Private Subnets ────────────────────────────────────────────────────────────
# EC2 instances (app tier) and RDS (data tier) live here.
# No public IPs — outbound access via NAT Gateway only.
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "private-subnet-${count.index + 1}-${var.region}"
    Tier = "private"
  })
}

# ── Elastic IPs for NAT Gateways ───────────────────────────────────────────────
# One EIP per public subnet = one NAT Gateway per AZ.
# If us-east-1a loses its NAT Gateway, instances in us-east-1b still have outbound
# access via their own NAT Gateway. Single-AZ NAT = single point of failure.
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "nat-eip-${count.index + 1}-${var.region}" })

  depends_on = [aws_internet_gateway.main]
}

# ── NAT Gateways ───────────────────────────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, { Name = "nat-gw-${count.index + 1}-${var.region}" })

  depends_on = [aws_internet_gateway.main]
}

# ── Public Route Table ─────────────────────────────────────────────────────────
# Single route table: all public subnets share the same 0.0.0.0/0 → IGW route.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "public-rt-${var.region}" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Tables ───────────────────────────────────────────────────────
# One route table per private subnet, each pointing to its own NAT Gateway.
# This provides AZ-level isolation: if one NAT Gateway goes down, only that AZ's
# private subnet loses outbound access — the other AZ is unaffected.
resource "aws_route_table" "private" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, { Name = "private-rt-${count.index + 1}-${var.region}" })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ── VPC Flow Logs ─────────────────────────────────────────────────────────────
# Captures all IP traffic metadata for the VPC — essential for security analysis
# and compliance. Logs to CloudWatch Logs.
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "flow-log-${var.region}" })
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/flow-log-${var.environment}-${var.region}"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_iam_role" "flow_log" {
  name = "vpc-flow-log-role-${var.environment}-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_log" {
  name = "vpc-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}
