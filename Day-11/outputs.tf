output "alb_dns_name" {
  description = "Paste in browser to test"
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

output "instance_type" {
  description = "Instance type used — driven by environment local"
  value       = local.instance_type
}

output "cluster_sizing" {
  description = "Min and max size — driven by environment local"
  value = {
    min = local.min_size
    max = local.max_size
  }
}

# -----------------------------
# SAFE CONDITIONAL OUTPUTS
# -----------------------------

# Without the ternary guard this would error when enable_monitoring = false:
# Error: Invalid index — the given key does not identify an element in this collection
#
# The guard returns null instead of erroring when the resource doesn't exist
output "high_cpu_alarm_arn" {
  description = "ARN of the high CPU alarm. Null if enable_monitoring = false."
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null
}

output "low_cpu_alarm_arn" {
  description = "ARN of the low CPU alarm. Null if enable_monitoring = false."
  value       = var.enable_monitoring ? aws_cloudwatch_metric_alarm.low_cpu[0].arn : null
}

output "monitoring_enabled" {
  description = "Whether monitoring resources were created"
  value       = var.enable_monitoring
}

output "vpc_id" {
  description = "VPC ID used — default or existing depending on use_existing_vpc"
  value       = local.vpc_id
}
