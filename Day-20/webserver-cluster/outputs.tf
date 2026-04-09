# Expose key outputs from the webserver-cluster module

output "alb_dns_name" {
  description = "DNS name of the load balancer — use this to access the app"
  value       = module.webserver_cluster.alb_dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.webserver_cluster.asg_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.webserver_cluster.alb_arn
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = module.webserver_cluster.target_group_arn
}

output "environment" {
  description = "Deployed environment"
  value       = var.environment
}

output "cluster_name" {
  description = "Cluster name"
  value       = var.cluster_name
}

output "instance_type_deployed" {
  description = "EC2 instance type deployed"
  value       = var.instance_type
}

output "cluster_sizing" {
  description = "Auto Scaling Group sizing"
  value       = "Min: ${var.min_size}, Max: ${var.max_size}"
}
