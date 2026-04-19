output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "DNS name of the Application Load Balancer. Open this URL in a browser to access the web application."
}

output "asg_name" {
  value       = module.asg.asg_name
  description = "Name of the Auto Scaling Group — use this in the AWS Console to monitor instance health"
}

output "cloudwatch_dashboard" {
  value       = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${module.asg.dashboard_name}"
  description = "URL to the CloudWatch dashboard showing CPU utilisation and instance count"
}

output "launch_template_id" {
  value       = module.ec2.launch_template_id
  description = "ID of the Launch Template used by the ASG"
}

output "target_group_arn" {
  value       = module.alb.target_group_arn
  description = "ARN of the ALB target group — verify healthy instances here in the AWS Console"
}

output "scale_out_alarm_arn" {
  value       = module.asg.cpu_high_alarm_arn
  description = "ARN of the CloudWatch alarm that triggers scale-out"
}

output "scale_in_alarm_arn" {
  value       = module.asg.cpu_low_alarm_arn
  description = "ARN of the CloudWatch alarm that triggers scale-in"
}
