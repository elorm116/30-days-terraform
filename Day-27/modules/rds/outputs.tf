output "db_instance_id" {
  value       = aws_db_instance.main.id
  description = "Identifier of the RDS instance"
}

output "db_instance_arn" {
  value       = aws_db_instance.main.arn
  description = "ARN of the RDS instance. For primary instances, this is passed to the replica module as replicate_source_db."
}

output "db_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "Connection endpoint (host:port) for the RDS instance"
  sensitive   = true
}

output "db_port" {
  value       = aws_db_instance.main.port
  description = "Port number for the RDS instance (3306 for MySQL)"
}

output "db_security_group_id" {
  value       = aws_security_group.rds.id
  description = "Security group ID of the RDS instance"
}

output "is_replica" {
  value       = var.is_replica
  description = "Whether this is a read replica (true) or primary (false)"
}

output "db_secret_arn" {
  value       = var.is_replica ? null : aws_secretsmanager_secret.db_master[0].arn
  description = "ARN of the Secrets Manager secret holding the RDS master credentials. Null for replicas."
  sensitive   = true
}
