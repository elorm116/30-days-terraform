# Outputs are defined in main.tf for this demo
output "vpc_id" {
  description = "VPC ID — read by app layer via terraform_remote_state"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Subnet ID — read by app layer via terraform_remote_state"
  value       = aws_subnet.main.id
}