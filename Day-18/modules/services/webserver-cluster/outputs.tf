output "alb_dns_name" {
  description = "ALB DNS name — paste in browser to test"
  value       = aws_lb.web.dns_name
}

output "asg_name" {
  description = "ASG name"
  value       = aws_autoscaling_group.web.name
}

output "environment" {
  description = "Deployed environment"
  value       = var.environment
}

output "instance_type_used" {
  description = "Actual instance type deployed — may differ from input if environment overrides"
  value       = local.instance_type
}

output "cluster_sizing" {
  description = "Actual min/max — may differ from input if environment overrides"
  value = {
    min = local.min_size
    max = local.max_size
  }
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.web.name
}

output "log_retention_days" {
  description = "Log retention period — 90 days production, 7 days dev"
  value       = local.log_retention_days
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts. Null if enable_monitoring = false."
  value       = var.enable_monitoring ? aws_sns_topic.alerts[0].arn : null
}

output "monitoring_enabled" {
  description = "Whether CloudWatch alarms were created"
  value       = var.enable_monitoring
}

output "common_tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}