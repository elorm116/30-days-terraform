output "public_ip" {
  value = aws_instance.web.public_ip
}


output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "instance_type" {
  description = "Instance type used in this environment"
  value       = aws_instance.web.instance_type
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}