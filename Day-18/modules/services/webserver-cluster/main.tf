provider "aws" {
  region = var.region
}

# -----------------------------
# LOCALS — THE HEART OF PRODUCTION-GRADE CODE
# -----------------------------

# common_tags is applied to EVERY resource via merge().
# Why this matters:
# - Cost allocation: filter AWS Cost Explorer by Environment or Project
# - Ownership: know who to call when something breaks at 3am
# - Automation: scripts can find resources by tag
# - Compliance: many security frameworks require resource tagging
#
# The merge() pattern means resources get both common tags AND
# resource-specific tags like Name without repeating the common ones.
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Owner       = var.team_name
    Cluster     = var.cluster_name
  }

  # Centralised conditional logic — all environment decisions in one place.
  # Resources reference clean local names instead of scattered ternaries.
  is_production      = var.environment == "production"
  instance_type      = local.is_production ? "t3.small" : var.instance_type
  min_size           = local.is_production ? 3 : var.min_size
  max_size           = local.is_production ? 10 : var.max_size
  health_check_grace = local.is_production ? 300 : 120
  log_retention_days = local.is_production ? 90 : 7
}

# -----------------------------
# DATA SOURCES
# -----------------------------

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

  exclude_zone_ids = ["use1-az3"]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availabilityZone"
    values = data.aws_availability_zones.available.names
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# -----------------------------
# SECURITY GROUPS
# -----------------------------

resource "aws_security_group" "alb_sg" {
  name   = "${var.cluster_name}-alb-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = var.alb_port
    to_port     = var.alb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # merge() combines common_tags with resource-specific tags.
  # Every resource gets Environment, ManagedBy, Project, Owner, Cluster
  # PLUS its own Name tag without repeating the common ones.
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-alb-sg"
  })
}

resource "aws_security_group" "web_sg" {
  name   = "${var.cluster_name}-web-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-web-sg"
  })
}

# -----------------------------
# LAUNCH TEMPLATE
# -----------------------------

resource "aws_launch_template" "web" {
  name_prefix   = "${var.cluster_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.instance_type

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd
    sed -i 's/^Listen 80$/Listen ${var.server_port}/' /etc/httpd/conf/httpd.conf
    systemctl enable httpd
    systemctl start httpd
    echo "<h1>${var.cluster_name} (${var.environment}) — ${var.app_version} 🚀</h1>" > /var/www/html/index.html
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    # merge() works on tag_specifications too
    tags = merge(local.common_tags, {
      Name    = "${var.cluster_name}-instance"
      Version = var.app_version
    })
  }

  # create_before_destroy on launch template ensures the new template
  # exists before the old one is destroyed during updates.
  # Without this: old template destroyed → ASG has no template → instances
  # can't launch → brief window of reduced capacity or errors.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-lt"
  })
}

# -----------------------------
# LOAD BALANCER
# -----------------------------

resource "aws_lb" "web" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id]
  internal           = false

  # Access logs for the ALB — production observability requirement.
  # Without this you have no record of what traffic hit your ALB.
  # Useful for debugging, security audits, and compliance.

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-alb"
  })
}

resource "aws_lb_target_group" "web" {
  name     = "${var.cluster_name}-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    port                = var.server_port
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = "404"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-listener"
  })
}

resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-listener-rule"
  })
}

# -----------------------------
# AUTO SCALING GROUP
# -----------------------------

resource "aws_autoscaling_group" "web" {
  name_prefix = "${var.cluster_name}-asg-"

  min_size         = local.min_size
  max_size         = local.max_size
  desired_capacity = local.min_size

  vpc_zone_identifier = data.aws_subnets.default.ids

  # ELB health checks — not EC2 health checks.
  # EC2 health checks only detect if the instance is running.
  # ELB health checks detect if the APP is responding correctly.
  # Without ELB health checks an instance with a crashed app
  # stays in service and receives traffic — silent failure.
  health_check_type         = "ELB"
  health_check_grace_period = local.health_check_grace

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web.arn]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}

# -----------------------------
# CLOUDWATCH LOG GROUP
# -----------------------------

# Log groups with retention prevent logs from accumulating forever.
# Without retention periods logs grow indefinitely and cost money.
# 90 days for production (compliance), 7 days for dev (cost saving).
resource "aws_cloudwatch_log_group" "web" {
  name              = "/aws/ec2/${var.cluster_name}"
  retention_in_days = local.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-logs"
  })
}

# -----------------------------
# SNS TOPIC — ALERT PIPELINE
# -----------------------------

# SNS is the notification hub. CloudWatch alarms send to SNS.
# SNS fans out to email, Slack, PagerDuty, Lambda, etc.
# This decouples alarms from notification channels —
# add a new subscriber without changing the alarm configuration.
resource "aws_sns_topic" "alerts" {
  count = var.enable_monitoring ? 1 : 0
  name  = "${var.cluster_name}-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-alerts"
  })
}

# Email subscription — commented out by default because it requires
# manual confirmation. Uncomment and set alarm_email to enable.
resource "aws_sns_topic_subscription" "email" {
  count     = var.enable_monitoring && var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# -----------------------------
# CLOUDWATCH ALARMS
# -----------------------------

# High CPU alarm — triggers when average CPU > threshold for 4 minutes.
# Why 4 minutes (2 periods × 2 minutes)?
# A single CPU spike isn't a problem — sustained high CPU is.
# 4 minutes gives enough signal to distinguish a real problem
# from a temporary burst.
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "CPU exceeded ${var.cpu_alarm_threshold}% for 4 minutes on ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  # When alarm fires → sends message to SNS topic → fans out to subscribers
  alarm_actions = var.enable_monitoring ? [aws_sns_topic.alerts[0].arn] : []
  ok_actions    = var.enable_monitoring ? [aws_sns_topic.alerts[0].arn] : []

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-high-cpu-alarm"
  })
}

# ALB 5xx error rate alarm — triggers when error rate is high.
# HTTP 5xx = server errors. A spike means your app is broken.
# This is often more actionable than CPU — it directly measures
# whether users are getting errors.
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is returning 5xx errors for ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.web.arn_suffix
  }

  alarm_actions = var.enable_monitoring ? [aws_sns_topic.alerts[0].arn] : []

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-alb-5xx-alarm"
  })
}

# Unhealthy hosts alarm — triggers when instances fail health checks.
# If this fires it means instances are running but the app is broken.
# Combined with high CPU alarm gives you a complete picture:
# high CPU + unhealthy hosts = app overloaded
# unhealthy hosts alone = app crashed, not overloaded
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "One or more instances are unhealthy in ${var.cluster_name}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.web.arn_suffix
    LoadBalancer = aws_lb.web.arn_suffix
  }

  alarm_actions = var.enable_monitoring ? [aws_sns_topic.alerts[0].arn] : []

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-unhealthy-hosts-alarm"
  })
}