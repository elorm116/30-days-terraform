terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }

  backend "s3" {
    bucket       = "dark-knight-terraform-state"
    key          = "webserver-cluster/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

# ── Local values ──────────────────────────────────────────────────────────────
locals {
  # These tags are merged onto every resource in this configuration.
  # The ManagedBy = "Terraform" tag is required by Sentinel policy
  # require-terraform-tag.sentinel — it MUST be present on every resource.
  common_tags = {
    ManagedBy   = "Terraform"          # Sentinel-enforced — do not remove
    Project     = "30DayTerraformChallenge"
    Day         = "22"
    Environment = terraform.workspace
    Owner       = "mali"
    Repository  = "github.com/elorm116/30-day-terraform-challenge"
  }
}

provider "aws" {
  region = var.aws_region

  # Default tags are applied to every resource that supports tagging.
  # This is the mechanism that satisfies the Sentinel tag policy at scale —
  # instead of adding tags to each resource individually, the provider applies
  # them universally. Individual resources can add additional tags but cannot
  # override the defaults.
  default_tags {
    tags = local.common_tags
  }
}

# ─── Data Sources ─────────────────────────────────────────────────────────────

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ─── S3 — State-adjacent: ALB access logs ────────────────────────────────────

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.cluster_name}-alb-logs-${terraform.workspace}"
  force_destroy = terraform.workspace != "prod"
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── Security Groups ──────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${var.cluster_name}-alb-sg-${terraform.workspace}"
  description = "Allow HTTP from internet to ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance" {
  name        = "${var.cluster_name}-instance-sg-${terraform.workspace}"
  description = "Allow traffic from ALB to EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "App port from ALB"
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── Launch Template ──────────────────────────────────────────────────────────

resource "aws_launch_template" "webserver" {
  name_prefix   = "${var.cluster_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    server_port  = var.server_port
    cluster_name = var.cluster_name
    environment  = terraform.workspace
  }))

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.instance.id]
  }

  monitoring {
    enabled = true  # Detailed CloudWatch monitoring — required for alarm accuracy
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2 — security best practice
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.cluster_name}-instance" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${var.cluster_name}-volume" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── Auto Scaling Group ───────────────────────────────────────────────────────

resource "aws_autoscaling_group" "webserver" {
  name                = "${var.cluster_name}-asg-${terraform.workspace}"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.webserver.arn]
  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.webserver.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# ─── Load Balancer ────────────────────────────────────────────────────────────

resource "aws_lb" "webserver" {
  name               = "${var.cluster_name}-alb-${terraform.workspace}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = terraform.workspace == "prod"

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }
}

resource "aws_lb_target_group" "webserver" {
  name     = "${var.cluster_name}-tg-${terraform.workspace}"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.webserver.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver.arn
  }
}

# ─── SNS + CloudWatch Alarms ──────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${var.cluster_name}-alerts-${terraform.workspace}"
}

resource "aws_sns_topic_subscription" "email" {
  count     = length(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.cluster_name}-cpu-high-${terraform.workspace}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold_high
  alarm_description   = "CPU above ${var.cpu_alarm_threshold_high}% for 10 min"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.webserver.name }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.cluster_name}-unhealthy-hosts-${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "One or more target group hosts are unhealthy"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = aws_lb.webserver.arn_suffix
    TargetGroup  = aws_lb_target_group.webserver.arn_suffix
  }
}

# ─── Auto Scaling Policies ────────────────────────────────────────────────────

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.cluster_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.webserver.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.cluster_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.webserver.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "scale_out_trigger" {
  alarm_name          = "${var.cluster_name}-scale-out-${terraform.workspace}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.webserver.name }
}

resource "aws_cloudwatch_metric_alarm" "scale_in_trigger" {
  alarm_name          = "${var.cluster_name}-scale-in-${terraform.workspace}"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 20
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.webserver.name }
}
