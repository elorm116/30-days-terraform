locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "scalable-web-app"
    Module      = "alb"
  })
}

# ── ALB Security Group ─────────────────────────────────────────────────────────
# The ALB is the only resource that accepts traffic directly from the internet.
# EC2 instances only accept traffic from this security group — never directly
# from the internet. This security boundary is enforced at the network layer.

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg-${var.environment}"
  description = "Allow HTTP/HTTPS inbound to ALB from internet; deny all else"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      description = "HTTPS from internet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "Allow all outbound - ALB needs to reach instances and health check endpoints"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name}-alb-sg-${var.environment}" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Application Load Balancer ──────────────────────────────────────────────────
resource "aws_lb" "web" {
  name               = "${var.name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  # Access logs capture every request for security analysis and debugging.
  # Disabled in dev to avoid S3 bucket dependency; enable in production.
  # access_logs {
  #   bucket  = var.access_log_bucket
  #   prefix  = "${var.name}-alb"
  #   enabled = true
  # }

  tags = merge(local.common_tags, { Name = "${var.name}-alb-${var.environment}" })
}

# ── Target Group ───────────────────────────────────────────────────────────────
# The target group is the bridge between the ALB and the ASG.
# The ASG registers its instances here; the ALB routes traffic to registered
# healthy instances. Health checks run from the ALB to each instance.
resource "aws_lb_target_group" "web" {
  name     = "${var.name}-tg-${var.environment}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = var.health_check_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = var.health_check_threshold
    unhealthy_threshold = var.unhealthy_threshold
    matcher             = "200"
    # Matching only 200 (not 200-299) ensures a partially-started app that
    # returns 301 or 302 redirects is NOT marked healthy.
  }

  # Deregistration delay: how long the ALB waits after deregistering an instance
  # before stopping traffic to it. Allows in-flight requests to complete.
  deregistration_delay = 30  # seconds; default is 300 — reduced for faster deploys in dev

  tags = merge(local.common_tags, { Name = "${var.name}-tg-${var.environment}" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── HTTP Listener ──────────────────────────────────────────────────────────────
# When HTTPS is enabled, HTTP should redirect to HTTPS.
# When HTTPS is disabled, HTTP forwards directly to the target group.
resource "aws_lb_listener" "http_forward" {
  count             = var.enable_https ? 0 : 1
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = merge(local.common_tags, { Name = "${var.name}-listener-http-${var.environment}" })
}

resource "aws_lb_listener" "http_redirect" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, { Name = "${var.name}-listener-http-${var.environment}" })
}

resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = merge(local.common_tags, { Name = "${var.name}-listener-https-${var.environment}" })
}

# ── CloudWatch Alarm — High Request Count ─────────────────────────────────────
# Fires when the target group is receiving more than threshold requests per
# target per minute. This is a traffic-based signal for scaling decisions,
# complementing the CPU-based alarms in the ASG module.
# In production, wire this to the ASG scale-out policy directly.
resource "aws_cloudwatch_metric_alarm" "high_request_count" {
  alarm_name          = "${var.name}-high-requests-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCountPerTarget"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.high_request_count_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.web.arn_suffix
    LoadBalancer = aws_lb.web.arn_suffix
  }

  alarm_description = "RequestCountPerTarget >= ${var.high_request_count_threshold}/min — consider scaling"

  tags = merge(local.common_tags, { Name = "${var.name}-high-requests-alarm-${var.environment}" })
}
