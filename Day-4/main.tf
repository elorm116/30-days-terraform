provider "aws" {
  region = var.region
}

# -----------------------------
# DATA SOURCES
# -----------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "all" {
  state = "available" # This excludes opted-out or unavailable AZs
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availabilityZone"
    values = data.aws_availability_zones.all.names
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
# SECURITY GROUP - ALB
# -----------------------------

resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = data.aws_vpc.default.id

  # Public Traffic comes in on Port 80
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
    Name = "alb-sg"
  }
}

# -----------------------------
# SECURITY GROUP - EC2 INSTANCES
# -----------------------------

resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = data.aws_vpc.default.id

  # Only allow traffic from the ALB Security Group on port 8080
  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # This only allows traffic from ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# -----------------------------
# LAUNCH TEMPLATE
# -----------------------------

resource "aws_launch_template" "web" {
  name          = "web-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf install -y httpd
              sed -i 's/^Listen 80$/Listen ${var.server_port}/' /etc/httpd/conf/httpd.conf
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from 30 Days Terraform Challenge. It is now highly available! 🚀</h1>" > /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "terraform-asg-instance"
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
  name               = "web-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id] # The ALB uses its own SG we defined earlier
}

# -----------------------------
# TARGET GROUP
# -----------------------------

resource "aws_lb_target_group" "web" {
  name     = "web-tg"
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

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = var.alb_port
  protocol          = "HTTP"

  # Default action — catches anything that doesn't match a rule below
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

resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  # Forward matching requests to the target group
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  # Match ALL paths — equivalent to your previous catch-all forward
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
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = 2

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
    value               = "terraform-asg"
    propagate_at_launch = true
  }
}