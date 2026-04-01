# -----------------------------
# DATA SOURCES
# -----------------------------

# We use the default VPC to keep things simple.
# In a production setup this would likely be a custom VPC
# passed in as a variable from a network module via terraform_remote_state.
data "aws_vpc" "default" {
  default = true
}

# Filter out us-east-1e — legacy AZ that doesn't support
# modern instance types like t3.micro.
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }

  exclude_zone_ids = ["use1-az3"]
}

# Only return subnets in valid AZs
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
# Pinning to most_recent means security patches
# are picked up automatically on the next apply.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# -----------------------------
# SECURITY GROUP - ALB
# -----------------------------

# This SG sits in front of the ALB.
# It accepts public internet traffic on the ALB port (80)
# and allows all outbound so the ALB can reach EC2 instances.
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

# -----------------------------
# SECURITY GROUP - EC2 INSTANCES
# -----------------------------

# This SG sits on the EC2 instances.
# It ONLY accepts traffic from the ALB SG — not from the internet directly.
# This means instances are unreachable unless traffic comes through the ALB.
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

# The launch template defines what every EC2 instance in the ASG looks like.
# user_data runs once when the instance boots — it installs httpd,
# reconfigures it to listen on server_port instead of 80,
# and drops a simple HTML page.
resource "aws_launch_template" "web" {
  name          = "${var.cluster_name}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf install -y httpd
    sed -i 's/^Listen 80$/Listen ${var.server_port}/' /etc/httpd/conf/httpd.conf
    systemctl enable httpd
    systemctl start httpd
    echo "<h1>${var.cluster_name} — ${var.custom_message} 🚀</h1>" > /var/www/html/index.html
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------
# LOAD BALANCER
# -----------------------------

# Application Load Balancer — sits in front of all EC2 instances.
# Distributes traffic across healthy instances in the ASG.
# internal = false means it's publicly accessible.
resource "aws_lb" "web" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id]
  internal           = false
}

# -----------------------------
# TARGET GROUP
# -----------------------------

# The target group is the list of EC2 instances the ALB forwards traffic to.
# Health checks run every 15 seconds — an instance needs 2 consecutive
# passing checks to be marked healthy, and 2 failures to be marked unhealthy.
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
}

# -----------------------------
# LISTENER
# -----------------------------

# The listener tells the ALB what to do with incoming traffic on port 80.
# Default action returns 404 for anything that doesn't match a rule.
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
# LISTENER RULE
# -----------------------------

# This rule matches ALL paths (/*) and forwards them to the target group.
# Priority 100 means it's evaluated before the default 404 action.
# In a multi-service setup you'd add more rules here with different
# path patterns pointing to different target groups.
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

# The ASG manages the fleet of EC2 instances.
# It uses ELB health checks so instances that fail the ALB
# health check are automatically replaced — not just EC2-level checks.
# health_check_grace_period gives httpd 300 seconds to start
# before the ASG starts evaluating health.
resource "aws_autoscaling_group" "web" {
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

  target_group_arns = [aws_lb_target_group.web.arn]

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-asg"
    propagate_at_launch = true
  }
}