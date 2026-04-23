output "primary_health_check_id" {
  value       = aws_route53_health_check.primary.id
  description = "ID of the Route53 health check for the primary region"
}

output "secondary_health_check_id" {
  value       = aws_route53_health_check.secondary.id
  description = "ID of the Route53 health check for the secondary region"
}

output "application_url" {
  value       = "http://${var.domain_name}"
  description = "Application URL via Route53 failover DNS"
}

output "primary_record_fqdn" {
  value       = aws_route53_record.primary.fqdn
  description = "FQDN of the primary DNS failover record"
}

output "secondary_record_fqdn" {
  value       = aws_route53_record.secondary.fqdn
  description = "FQDN of the secondary DNS failover record"
}

output "primary_health_check_alarm_arn" {
  value       = aws_cloudwatch_metric_alarm.primary_health.arn
  description = "ARN of the CloudWatch alarm that fires when the primary health check fails"
}
