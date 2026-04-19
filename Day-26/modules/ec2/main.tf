locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "scalable-web-app"
    Module      = "ec2"
  })
}

# ── Security Group ─────────────────────────────────────────────────────────────
# Instances only accept traffic from the ALB security group — not from the
# internet directly. This is a key security design: the ALB is the only public
# entry point; instances are effectively private even if in a public subnet.

resource "aws_security_group" "instance" {
  name        = "${var.app_name}-instance-sg-${var.environment}"
  description = "Allow HTTP from ALB only; deny all direct internet access to instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
    # SECURITY: instances are not directly internet-accessible.
    # Only the ALB SG is allowed as an ingress source.
  }

  egress {
    description = "Allow all outbound (package installs, AWS API calls)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.app_name}-instance-sg-${var.environment}" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Launch Template ────────────────────────────────────────────────────────────
# Launch Templates replace the older Launch Configurations — they support
# versioning, instance type overrides, and spot fleet configuration.
# The ASG module always references "$Latest" so rolling out a new AMI is as
# simple as updating the template and triggering an instance refresh.

resource "aws_launch_template" "web" {
  name_prefix   = "${var.app_name}-lt-${var.environment}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.instance.id]

  # IMDSv2 required — prevents SSRF attacks reaching instance metadata
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # User data bootstraps Apache on first boot.
  # In production this would pull a versioned artifact (RPM, container image)
  # rather than installing directly — but httpd is sufficient to prove the
  # end-to-end infrastructure path works.
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
    app_name    = var.app_name
    server_port = var.server_port
  }))

  # Propagate tags to the EBS root volume as well
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-${var.environment}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-vol-${var.environment}" })
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${var.app_name}-lt-${var.environment}" })
}
