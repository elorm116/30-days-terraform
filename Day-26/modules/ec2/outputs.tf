output "launch_template_id" {
  value       = aws_launch_template.web.id
  description = "ID of the Launch Template — consumed by the ASG module as launch_template_id"
}

output "launch_template_version" {
  value       = aws_launch_template.web.latest_version
  description = "Latest version number of the Launch Template — ASG uses this to pin to the reviewed version rather than blindly using $Latest"
}

output "security_group_id" {
  value       = aws_security_group.instance.id
  description = "Security group ID attached to EC2 instances — passed back to callers for reference or additional rules"
}

output "launch_template_name" {
  value       = aws_launch_template.web.name
  description = "Full name of the Launch Template (includes the random suffix from name_prefix)"
}
