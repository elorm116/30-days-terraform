locals {
  day21_enable_alarm_actions = var.enable_monitoring && length(trimspace(var.alarm_email)) > 0
  day21_alarm_actions        = local.day21_enable_alarm_actions ? [aws_sns_topic.day21_alarms[0].arn] : []
}

resource "aws_sns_topic" "day21_alarms" {
  count = local.day21_enable_alarm_actions ? 1 : 0

  name = "${var.cluster_name}-${var.environment}-day21-alarms"
}

resource "aws_sns_topic_subscription" "day21_alarm_email" {
  count = local.day21_enable_alarm_actions ? 1 : 0

  topic_arn = aws_sns_topic.day21_alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_metric_alarm" "day21_asg_cpu_high" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-${var.environment}-day21-asg-cpu-high"
  alarm_description   = "Day 21: Average EC2 CPU across the ASG is above threshold."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = var.cpu_alarm_threshold

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"
  period      = 60

  dimensions = {
    AutoScalingGroupName = module.webserver_cluster.asg_name
  }

  treat_missing_data = "notBreaching"

  alarm_actions = local.day21_alarm_actions
  ok_actions    = local.day21_alarm_actions
}
