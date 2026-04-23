output "primary_alb_dns" {
  value       = module.alb_primary.alb_dns_name
  description = "Primary region ALB (us-east-1) — bypass Route53"
}

output "secondary_alb_dns" {
  value       = module.alb_secondary.alb_dns_name
  description = "Secondary region ALB (us-west-2) — bypass Route53"
}

output "app_name" {
  value       = var.app_name
  description = "The name of the application"
}

output "primary_db_endpoint" {
  value       = module.rds_primary.db_endpoint
  description = "Primary RDS endpoint"
  sensitive = true
}

output "secondary_db_endpoint" {
  value       = module.rds_replica.db_endpoint
  description = "Secondary RDS endpoint"
  sensitive = true
}
