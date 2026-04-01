output "alb_dns_name" {
  description = "Hit this URL to test the cluster"
  value       = aws_lb.web.dns_name
}

output "active_environment" {
  description = "Which environment is currently receiving traffic"
  value       = var.active_environment
}

output "app_version" {
  description = "Currently deployed application version"
  value       = var.app_version
}

output "asg_name" {
  description = "Current ASG name — changes with every zero-downtime deployment"
  value       = aws_autoscaling_group.web.name
}

output "blue_tg_arn" {
  description = "Blue target group ARN"
  value       = aws_lb_target_group.blue.arn
}

output "green_tg_arn" {
  description = "Green target group ARN"
  value       = aws_lb_target_group.green.arn
}