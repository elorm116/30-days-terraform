output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.webserver.dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.webserver.name
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.webserver.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.webserver.arn
}

output "security_group_alb_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

output "security_group_instance_id" {
  description = "Security group ID for EC2 instances"
  value       = aws_security_group.instance.id
}

output "cloudwatch_alarm_cpu_high_arn" {
  description = "ARN of the high CPU alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

output "cloudwatch_alarm_unhealthy_hosts_arn" {
  description = "ARN of the unhealthy hosts alarm"
  value       = aws_cloudwatch_metric_alarm.unhealthy_hosts.arn
}

output "sns_topic_alarms_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = try(aws_sns_topic.alarms[0].arn, null)
}
