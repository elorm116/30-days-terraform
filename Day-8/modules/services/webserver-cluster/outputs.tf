# The ALB DNS name is what you paste in the browser to test.
# Exposed as an output so the calling configuration can surface it
# after terraform apply without having to dig through the console.
output "alb_dns_name" {
  description = "Public DNS name of the load balancer — paste this in your browser"
  value       = aws_lb.web.dns_name
}

# The ASG name is useful for the caller to reference in other resources
# like autoscaling policies, CloudWatch alarms, or CI/CD pipelines
# that need to trigger scale events.
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

# The ALB ARN is useful if a caller wants to add more listeners
# or attach WAF rules to the same ALB without recreating it.
output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.web.arn
}