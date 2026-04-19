locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "scalable-web-app"
    Module      = "asg"
  })

  asg_name = "${var.app_name}-asg-${var.environment}"
}

data "aws_region" "current" {}

# ── Auto Scaling Group ─────────────────────────────────────────────────────────
# The ASG is the orchestrator. It:
#   1. Launches instances using the Launch Template (from the EC2 module)
#   2. Registers those instances with the ALB target group (from the ALB module)
#   3. Runs health checks using the ALB health check results (not just EC2 checks)
#   4. Replaces unhealthy instances automatically
#   5. Scales out/in based on CloudWatch alarms defined below

resource "aws_autoscaling_group" "web" {
  name                = local.asg_name
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns

  launch_template {
    id      = var.launch_template_id
    version = var.launch_template_version
  }

  
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  force_delete = var.force_delete

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

  # Instance refresh: when the Launch Template version changes (e.g. new AMI),
  # the ASG rolls out the new template to running instances automatically.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      # Replace 50% of instances at a time. With 2 instances: replace 1,
      # wait for it to be healthy, then replace the other.
    }
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${var.app_name}-${var.environment}" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# ── Scaling Policies ───────────────────────────────────────────────────────────
# Simple scaling policies: add or remove exactly one instance at a time.
# Step scaling (multiple steps based on alarm severity) is more sophisticated
# but simple scaling is easier to understand and debug, and appropriate for
# most web application workloads.

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${local.asg_name}-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.scale_out_cooldown
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${local.asg_name}-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.scale_in_cooldown
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# ── CloudWatch Alarms ─────────────────────────────────────────────────────────
# These alarms close the feedback loop:
#   CPU rises above threshold → alarm fires → scale-out policy → new instance
#   CPU drops below threshold → alarm fires → scale-in policy → instance removed
#
# evaluation_periods = 2: the alarm must be in ALARM state for two consecutive
# 120-second periods (4 minutes total) before triggering. This prevents
# momentary CPU spikes from causing unnecessary scale-out events.

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

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "Scale OUT: average CPU >= ${var.cpu_scale_out_threshold}% for 4 minutes"
  alarm_actions     = [aws_autoscaling_policy.scale_out.arn]

  tags = merge(local.common_tags, { Name = "${local.asg_name}-cpu-high-alarm" })
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

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_description = "Scale IN: average CPU <= ${var.cpu_scale_in_threshold}% for 4 minutes"
  alarm_actions     = [aws_autoscaling_policy.scale_in.arn]

  tags = merge(local.common_tags, { Name = "${local.asg_name}-cpu-low-alarm" })
}

# ── CloudWatch Dashboard  ───────────────────────────────────────────────
resource "aws_cloudwatch_dashboard" "web" {
  dashboard_name = "${local.asg_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "CPU Utilization (%) — Scale-out at ${var.cpu_scale_out_threshold}%, scale-in at ${var.cpu_scale_in_threshold}%"
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          region = data.aws_region.current.id
          annotations = {
            horizontal = [
              { label = "Scale-out threshold", value = var.cpu_scale_out_threshold, color = "#f85149" },
              { label = "Scale-in threshold", value = var.cpu_scale_in_threshold, color = "#3fb950" }
            ]
          }
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.web.name,
              { label = "Average CPU %", color = "#79c0ff" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ASG Instance Count (min: ${var.min_size}, max: ${var.max_size})"
          period = 60
          stat   = "Average"
          view   = "timeSeries"
          region = data.aws_region.current.id
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.web.name,
              { label = "In-Service Instances", color = "#3fb950" }],
            ["AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", aws_autoscaling_group.web.name,
              { label = "Desired Capacity", color = "#d29922" }]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 6
        width  = 24
        height = 4
        properties = {
          title  = "Scaling Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.cpu_high.arn,
            aws_cloudwatch_metric_alarm.cpu_low.arn
          ]
        }
      }
    ]
  })
}
