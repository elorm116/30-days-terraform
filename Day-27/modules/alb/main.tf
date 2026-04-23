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
  # ALB names have a 32-character limit — truncate region suffix if needed
  alb_name = substr("${var.name}-alb-${replace(var.region, "-", "")}", 0, 32)
  tg_name  = substr("${var.name}-tg-${replace(var.region, "-", "")}", 0, 32)
}

# ── ALB Security Group ─────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg-${var.region}"
  description = "Allow HTTP/HTTPS from internet to ALB. Deny all else"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags, 
    { Name = "${var.name}-alb-sg-${var.region}" }
    )

  lifecycle { 
    create_before_destroy = true 
    }
}

# ── Application Load Balancer ──────────────────────────────────────────────────
resource "aws_lb" "web" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(local.common_tags, { Name = local.alb_name })
}

# ── Target Group ───────────────────────────────────────────────────────────────
resource "aws_lb_target_group" "web" {
  name                 = local.tg_name
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = var.deregistration_delay

  health_check {
    path                = var.health_check_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = merge(local.common_tags, { Name = local.tg_name })

  lifecycle { create_before_destroy = true }
}

# ── HTTP Listener ──────────────────────────────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = merge(local.common_tags, { Name = "${var.name}-listener-${var.region}" })
}
