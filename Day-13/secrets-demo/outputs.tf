# -----------------------------
# SENSITIVE OUTPUTS
# -----------------------------

# sensitive = true on outputs prevents the value from appearing
# in terraform apply output or CI/CD logs.
# Without it the connection string would print to terminal
# and potentially get captured in CI/CD logs.
#
# The value is still in state — sensitive = true only
# controls terminal/log visibility not state storage.
output "db_endpoint" {
  description = "RDS endpoint — sensitive because it reveals infrastructure topology"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_connection_string" {
  description = "MySQL connection string — sensitive because it contains endpoint and username"
  value       = "mysql://${aws_db_instance.main.username}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

# Non-sensitive outputs — safe to print
output "db_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "db_engine" {
  description = "Database engine and version"
  value       = "${aws_db_instance.main.engine} ${aws_db_instance.main.engine_version}"
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret — not sensitive, just a reference"
  value       = data.aws_secretsmanager_secret.db_credentials.arn
}