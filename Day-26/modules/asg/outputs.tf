output "asg_name" {
  value       = aws_autoscaling_group.web.name
  description = "Name of the Auto Scaling Group"
}

output "asg_arn" {
  value       = aws_autoscaling_group.web.arn
  description = "ARN of the Auto Scaling Group"
}

output "scale_out_policy_arn" {
  value       = aws_autoscaling_policy.scale_out.arn
  description = "ARN of the CPU scale-out policy — can be referenced by external alarms"
}

output "scale_in_policy_arn" {
  value       = aws_autoscaling_policy.scale_in.arn
  description = "ARN of the CPU scale-in policy — can be referenced by external alarms"
}

output "cpu_high_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
  description = "ARN of the high-CPU CloudWatch alarm"
}

output "cpu_low_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.cpu_low.arn
  description = "ARN of the low-CPU CloudWatch alarm"
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.web.dashboard_name
  description = "Name of the CloudWatch dashboard — access it at https://console.aws.amazon.com/cloudwatch/home#dashboards:"
}
