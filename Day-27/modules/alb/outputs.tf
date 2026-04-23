output "alb_dns_name" {
  value       = aws_lb.web.dns_name
  description = "DNS name of the ALB — passed to Route53 module as an alias target"
}

output "alb_zone_id" {
  value       = aws_lb.web.zone_id
  description = "Canonical hosted zone ID of the ALB — required for Route53 ALIAS records"
}

output "alb_arn" {
  value       = aws_lb.web.arn
  description = "ARN of the ALB"
}

output "alb_arn_suffix" {
  value       = aws_lb.web.arn_suffix
  description = "ARN suffix for use in CloudWatch metric dimensions"
}

output "target_group_arn" {
  value       = aws_lb_target_group.web.arn
  description = "Target group ARN — passed to ASG module as target_group_arns to register instances"
}

output "target_group_arn_suffix" {
  value       = aws_lb_target_group.web.arn_suffix
  description = "Target group ARN suffix for CloudWatch dimensions"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "ALB security group ID — passed to ASG module so instances only accept traffic from the ALB"
}
