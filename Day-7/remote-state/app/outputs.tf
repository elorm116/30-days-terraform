output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "vpc_id" {
  description = "VPC ID the instance was deployed into"
  value       = data.terraform_remote_state.network.outputs.vpc_id
}

output "subnet_id" {
  description = "Subnet ID the instance was deployed into"
  value       = data.terraform_remote_state.network.outputs.subnet_id
}