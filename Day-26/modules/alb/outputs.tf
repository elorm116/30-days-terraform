output "alb_dns_name" {
  value       = aws_lb.web.dns_name
  description = "DNS name of the Application Load Balancer. Use this URL to access the application."
}

output "alb_arn" {
  value       = aws_lb.web.arn
  description = "ARN of the Application Load Balancer"
}

output "alb_arn_suffix" {
  value       = aws_lb.web.arn_suffix
  description = "ARN suffix of the ALB — used in CloudWatch metric dimensions"
}

output "target_group_arn" {
  value       = aws_lb_target_group.web.arn
  description = "ARN of the ALB target group. CONSUMED BY ASG MODULE via target_group_arns input — this is the link that registers ASG instances with the ALB."
}

output "target_group_arn_suffix" {
  value       = aws_lb_target_group.web.arn_suffix
  description = "ARN suffix of the target group — used in CloudWatch metric dimensions"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb.id
  description = "Security group ID of the ALB. CONSUMED BY EC2 MODULE — passed as alb_security_group_id so instances only accept traffic from the ALB, not from the internet directly."
}

output "alb_zone_id" {
  value       = aws_lb.web.zone_id
  description = "Canonical hosted zone ID of the ALB — used for Route 53 ALIAS records"
}
