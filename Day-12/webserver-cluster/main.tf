
provider "aws" {
  region = var.region
}

# -----------------------------
# DATA SOURCES
# -----------------------------

# We exclude us-east-1e because it doesn't support t3.micro.
# You've seen this bite us before — excluding it here permanently.
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

# Always use the latest Amazon Linux 2023 AMI.
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

  tags = {
    Name = "${var.cluster_name}-alb-sg"
  }
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

  tags = {
    Name = "${var.cluster_name}-web-sg"
  }
}

# -----------------------------
# LAUNCH TEMPLATE
# -----------------------------

# The launch template defines what every EC2 instance looks like.
# When app_version changes, this resource changes.
# Because the ASG references this launch template and has
# create_before_destroy = true, changing app_version triggers
# a full zero-downtime replacement of the ASG.
resource "aws_launch_template" "web" {
  # name_prefix is critical here.
  # When create_before_destroy = true, the NEW launch template
  # must be created BEFORE the old one is destroyed.
  # AWS doesn't allow two launch templates with the same name
  # to exist simultaneously — name_prefix lets AWS generate
  # a unique suffix so both can coexist during the transition.
  name_prefix   = "${var.cluster_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # The app_version variable appears in the HTML response.
  # Changing v1 to v2 updates this user_data which forces
  # a new launch template version and triggers ASG replacement.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd
    sed -i 's/^Listen 80$/Listen ${var.server_port}/' /etc/httpd/conf/httpd.conf
    systemctl enable httpd
    systemctl start httpd
    echo "<h1>${var.cluster_name} — Hello World ${var.app_version} 🚀</h1>" > /var/www/html/index.html
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.cluster_name}-instance"
      Version = var.app_version
    }
  }

  # create_before_destroy on the launch template ensures
  # the new template exists before the old one is removed.
  # This cascades to the ASG — the ASG also needs this lifecycle rule.
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
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id]
  internal           = false
}

# -----------------------------
# TARGET GROUPS — BLUE AND GREEN
# -----------------------------

# We create TWO target groups — one for blue, one for green.
# Both always exist. The ALB listener rule decides which one
# receives live traffic based on var.active_environment.
#
# Blue = current stable version
# Green = new version being tested
#
# Switching traffic is a single variable change + terraform apply.
# The ALB updates the listener rule in one API call — instantaneous.
resource "aws_lb_target_group" "blue" {
  name     = "${var.cluster_name}-blue-tg"
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

  tags = {
    Name = "${var.cluster_name}-blue-tg"
  }
}

resource "aws_lb_target_group" "green" {
  name     = "${var.cluster_name}-green-tg"
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

  tags = {
    Name = "${var.cluster_name}-green-tg"
  }
}

# -----------------------------
# LISTENER
# -----------------------------

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

# -----------------------------
# LISTENER RULE — BLUE/GREEN SWITCH
# -----------------------------

# This is the heart of blue/green deployment.
# The ternary operator chooses which target group receives traffic.
# active_environment = "blue"  → all traffic goes to blue target group
# active_environment = "green" → all traffic goes to green target group
#
# When you change active_environment and run terraform apply,
# AWS updates this listener rule in a single API call.
# There is no window where traffic is dropped — it's atomic.
resource "aws_lb_listener_rule" "blue_green" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = var.active_environment == "blue" ? aws_lb_target_group.blue.arn : aws_lb_target_group.green.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# -----------------------------
# AUTO SCALING GROUP
# -----------------------------

# The ASG manages the fleet of EC2 instances.
#
# name_prefix instead of name — CRITICAL for zero-downtime.
# When create_before_destroy = true, the new ASG must exist
# alongside the old one before the old is destroyed.
# AWS doesn't allow two ASGs with identical names simultaneously.
# name_prefix tells AWS to generate a unique suffix automatically:
# webservers-day12-asg-20260327182007 (old)
# webservers-day12-asg-20260327195431 (new)
# Both exist during the transition. Old is destroyed after new is healthy.
resource "aws_autoscaling_group" "web" {
  name_prefix = "${var.cluster_name}-asg-"

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.min_size

  vpc_zone_identifier = data.aws_subnets.default.ids

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Both target groups are attached to the ASG.
  # This means instances register with both blue and green.
  # The listener rule controls which target group receives traffic —
  # not which target group has instances registered.
  target_group_arns = [
    aws_lb_target_group.blue.arn,
    aws_lb_target_group.green.arn
  ]

  # create_before_destroy reverses Terraform's default behaviour.
  #
  # DEFAULT (destroy-then-create):
  # 1. Old ASG destroyed → instances terminated → APP DOWN
  # 2. New ASG created → instances spin up → app back up
  # Downtime = time between steps 1 and 2 (can be minutes)
  #
  # create_before_destroy:
  # 1. New ASG created → instances spin up → pass health checks
  # 2. Old ASG destroyed → traffic already on new instances
  # Downtime = zero

  # This is the missing piece.
  # When the launch template changes, instance_refresh
  # triggers a rolling replacement of all running instances.
  # min_healthy_percentage = 50 means at least 50% of instances
  # must be healthy at all times during the replacement.
  # So with 2 instances: replace 1, wait for it to be healthy,
  # then replace the other. No downtime.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }

    triggers = ["launch_template"]


  }
# #   lifecycle {
# #     create_before_destroy = true
#   }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Version"
    value               = var.app_version
    propagate_at_launch = true
  }
}