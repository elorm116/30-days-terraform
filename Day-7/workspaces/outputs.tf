output "workspace" {
  value = terraform.workspace
}

output "instance_type" {
  value = aws_instance.web.instance_type
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
