# -----------------------------
# LOCALS — all conditional decisions in one place
# -----------------------------

# This is the correct pattern. Instead of scattering ternary operators
# through resource arguments like this:
#   instance_type = var.environment == "production" ? "t3.small" : "t3.micro"
#   min_size      = var.environment == "production" ? 3 : 1
#
# We centralise everything in locals. Resources just reference clean names.
# One place to change, everything picks it up.
locals {
  is_production = var.environment == "production"
  is_dev        = var.environment == "dev"

  # Instance sizing — production gets larger instances
  instance_type = local.is_production ? "t3.small" : "t3.micro"

  # Cluster sizing — production runs more instances
  min_size = local.is_production ? 3 : local.is_dev ? 1 : 2
  max_size = local.is_production ? 10 : local.is_dev ? 3 : 5

  # Monitoring thresholds — production is more sensitive
  scale_out_threshold = local.is_production ? 70 : 90
  scale_in_threshold  = local.is_production ? 30 : 20

  # Health check grace period — production gets more time
  health_check_grace = local.is_production ? 300 : 120
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

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# -----------------------------
# CONDITIONAL DATA SOURCE — brownfield vs greenfield VPC
# -----------------------------

# Greenfield: use_existing_vpc = false → create nothing here,
#             use the default VPC via aws_vpc.default data source below
# Brownfield: use_existing_vpc = true  → look up an existing VPC by name tag
#
# count = 1 → data source is queried
# count = 0 → data source is skipped entirely
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0

  tags = {
    Name = var.existing_vpc_name
  }
}

# Always available fallback — the default VPC
# Used when use_existing_vpc = false
data "aws_vpc" "default" {
  count   = var.use_existing_vpc ? 0 : 1
  default = true
}

# Centralise the VPC ID decision in locals
# so resources always just reference local.vpc_id
locals {
  vpc_id = var.use_existing_vpc ? data.aws_vpc.existing[0].id : data.aws_vpc.default[0].id
}

data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "availabilityZone"
    values = data.aws_availability_zones.available.names
  }
}

# -----------------------------
# SECURITY GROUPS
# -----------------------------

resource "aws_security_group" "alb_sg" {
  name   = "${var.cluster_name}-alb-sg"
  vpc_id = local.vpc_id

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

  tags = {
    Name        = "${var.cluster_name}-alb-sg"
    Environment = var.environment
  }
}

resource "aws_security_group" "web_sg" {
  name   = "${var.cluster_name}-web-sg"
  vpc_id = local.vpc_id

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

  tags = {
    Name        = "${var.cluster_name}-web-sg"
    Environment = var.environment
  }
}

# -----------------------------
# LAUNCH TEMPLATE
# -----------------------------

resource "aws_launch_template" "web" {
  name          = "${var.cluster_name}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = local.instance_type  # ← from locals, not hardcoded

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd
    sed -i 's/^Listen 80$/Listen ${var.server_port}/' /etc/httpd/conf/httpd.conf
    systemctl enable httpd
    systemctl start httpd
    echo "<h1>${var.cluster_name} (${var.environment}) — ${var.custom_message} 🚀</h1>" > /var/www/html/index.html
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-instance"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------
# LOAD BALANCER
# -----------------------------

resource "aws_lb" "web" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.available.ids
  security_groups    = [aws_security_group.alb_sg.id]
  internal           = false
}

resource "aws_lb_target_group" "web" {
  name     = "${var.cluster_name}-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/"
    port                = var.server_port
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }
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
      status_code  = 404
    }
  }
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
}

# -----------------------------
# AUTO SCALING GROUP
# -----------------------------

resource "aws_autoscaling_group" "web" {
  min_size         = local.min_size  # ← from locals
  max_size         = local.max_size  # ← from locals
  desired_capacity = local.min_size

  vpc_zone_identifier = data.aws_subnets.available.ids

  health_check_type         = "ELB"
  health_check_grace_period = local.health_check_grace  # ← from locals

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web.arn]

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# -----------------------------
# OPTIONAL — AUTOSCALING POLICIES
# -----------------------------

# count = 1 → created
# count = 0 → skipped entirely
# Gated by enable_monitoring so dev doesn't pay for
# CloudWatch alarms it doesn't need
resource "aws_autoscaling_policy" "scale_out" {
  count = var.enable_monitoring ? 1 : 0

  name                   = "${var.cluster_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  count = var.enable_monitoring ? 1 : 0

  name                   = "${var.cluster_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# -----------------------------
# OPTIONAL — CLOUDWATCH ALARMS
# -----------------------------

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = local.scale_out_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = local.scale_in_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in[0].arn]
}