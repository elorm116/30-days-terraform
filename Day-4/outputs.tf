# Output the Public IP so you can test it immediately
output "ec2_instance_ip" {
  description = "Public IP of the web server"
  value = aws_instance.web-server.public_ip
}

output "alb_dns_name" {
  description = "Public DNS of the Load Balancer"
  value       = aws_lb.web.dns_name
}