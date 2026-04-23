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
  asg_name = "${var.app_name}-asg-${var.environment}-${var.region}"
}


# ── IAM Role for EC2 instances ─────────────────────────────────────────────────
# Allows instances to call secretsmanager:GetSecretValue for the DB secret.
# Without this, user_data cannot retrieve the password at boot.
resource "aws_iam_role" "instance" {
  name = "${var.app_name}-instance-role-${var.environment}-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "db-secret-read"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = var.db_secret_arn
    }]
  })
}

# SSM Session Manager — lets you shell into instances without opening port 22
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.app_name}-instance-profile-${var.environment}-${var.region}"
  role = aws_iam_role.instance.name
}

# ── Instance Security Group ────────────────────────────────────────────────────
# Only allows inbound from the ALB SG — not from the internet.
resource "aws_security_group" "instance" {
  name        = "${var.app_name}-instance-sg-${var.environment}-${var.region}"
  description = "Allow HTTP from ALB SG only; deny all direct internet access"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.app_name}-instance-sg-${var.region}" })

  lifecycle { create_before_destroy = true }
}

# ── Launch Template ────────────────────────────────────────────────────────────
resource "aws_launch_template" "web" {
  name_prefix   = "${var.app_name}-lt-${var.environment}-${var.region}-"
  image_id      = var.launch_template_ami
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  # IMDSv2 required — prevents SSRF attacks from reaching instance metadata
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    set -euo pipefail

    # ── IMDSv2 token ───────────────────────────────────────────────────────────
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/placement/availability-zone)
    REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/placement/region)

    # ── Fetch DB credentials from Secrets Manager ──────────────────────────────
    # The secret is a JSON blob: {"username":"...","password":"..."}
    # We use the AWS CLI (pre-installed on AL2023) with the instance role —
    # no credentials on disk, no env vars, no plaintext anywhere.
    SECRET=$(aws secretsmanager get-secret-value \
      --secret-id "${var.db_secret_arn}" \
      --region "$REGION" \
      --query SecretString \
      --output text)

    DB_USER=$(echo "$SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
    DB_PASS=$(echo "$SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

    # Write to a root-only env file — never world-readable
    install -m 600 -o root -g root /dev/null /etc/db.env
    echo "DB_USER=$$DB_USER" >> /etc/db.env
    echo "DB_PASS=$$DB_PASS" >> /etc/db.env

    # Clear variables from memory
    unset SECRET DB_USER DB_PASS

    # ── Write index.html ───────────────────────────────────────────────────────
    cat > /var/www/html/index.html <<HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Multi-Region HA — ${var.region}</title>
      <style>
        body{font-family:monospace;background:#0d1117;color:#e6edf3;
             display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}
        .card{background:#161b22;border:1px solid #30363d;border-radius:8px;
              padding:32px 40px;text-align:center;max-width:460px}
        .badge{background:#7c3aed;color:#fff;padding:3px 12px;border-radius:4px;
               font-size:11px;font-weight:700;letter-spacing:1px;display:inline-block;margin-bottom:16px}
        .region{font-size:20px;font-weight:700;color:#3fb950;margin-bottom:12px}
        .meta{color:#8b949e;font-size:13px;line-height:1.9}
        .hl{color:#79c0ff}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="badge">MULTI-REGION HA · DAY 27</div>
        <div class="region">📍 ${var.region}</div>
        <div class="meta">
          <div>Environment: <span class="hl">${var.environment}</span></div>
          <div>Instance: <span class="hl">$$INSTANCE_ID</span></div>
          <div>AZ: <span class="hl">$$AZ</span></div>
        </div>
      </div>
    </body>
    </html>
    HTML

    # httpd is pre-baked — just start it
    systemctl start httpd
  USERDATA
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-${var.environment}-${var.region}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${var.app_name}-vol-${var.environment}-${var.region}" })
  }

  lifecycle { create_before_destroy = true }
}

# ── Auto Scaling Group ─────────────────────────────────────────────────────────
resource "aws_autoscaling_group" "web" {
  name                = local.asg_name
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${var.app_name}-${var.environment}-${var.region}" })
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

# ── Scaling Policies ───────────────────────────────────────────────────────────
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${local.asg_name}-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${local.asg_name}-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 600
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.asg_name}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = var.cpu_scale_out_threshold
  treat_missing_data  = "notBreaching"

  dimensions = { AutoScalingGroupName = aws_autoscaling_group.web.name }

  alarm_description = "Scale OUT: CPU >= ${var.cpu_scale_out_threshold}% for 4 min"
  alarm_actions     = [aws_autoscaling_policy.scale_out.arn]

  tags = merge(local.common_tags, { Name = "${local.asg_name}-cpu-high" })
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.asg_name}-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = var.cpu_scale_in_threshold
  treat_missing_data  = "notBreaching"

  dimensions = { AutoScalingGroupName = aws_autoscaling_group.web.name }

  alarm_description = "Scale IN: CPU <= ${var.cpu_scale_in_threshold}% for 4 min"
  alarm_actions     = [aws_autoscaling_policy.scale_in.arn]

  tags = merge(local.common_tags, { Name = "${local.asg_name}-cpu-low" })
}
