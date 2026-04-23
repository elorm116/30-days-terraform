variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for your domain. Route53 is global — no provider alias needed."
  type        = string
}

variable "domain_name" {
  description = "FQDN for the application (e.g. app.example.com). Route53 creates A records at this name."
  type        = string
}

variable "primary_alb_dns_name" {
  description = "DNS name of the primary region ALB — used as the alias target for the PRIMARY failover record"
  type        = string
}

variable "primary_alb_zone_id" {
  description = "Canonical hosted zone ID of the primary ALB — required for Route53 ALIAS records"
  type        = string
}

variable "secondary_alb_dns_name" {
  description = "DNS name of the secondary region ALB — used as the alias target for the SECONDARY failover record"
  type        = string
}

variable "secondary_alb_zone_id" {
  description = "Canonical hosted zone ID of the secondary ALB"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region identifier (e.g. us-east-1)"
  type        = string
}

variable "secondary_region" {
  description = "Secondary AWS region identifier (e.g. us-west-2)"
  type        = string
}

variable "health_check_failure_threshold" {
  description = "Number of consecutive health check failures before Route53 marks the endpoint unhealthy"
  type        = number
  default     = 3
  # 3 failures × 30-second interval = 90 seconds before DNS failover begins.
  # Lower = faster failover; higher = less risk of false-positive failover.
}

variable "health_check_request_interval" {
  description = "Seconds between Route53 health check requests to each ALB endpoint"
  type        = number
  default     = 30
  # 10-second intervals available on Standard health checks (more expensive).
  # 30-second is the default and sufficient for most workloads.
}

variable "ttl" {
  description = "DNS TTL for non-alias records (seconds). Lower TTL = faster propagation but higher Route53 query costs."
  type        = number
  default     = 60
  # Alias records to ALBs always use TTL = 60 regardless of this value.
}

variable "tags" {
  description = "Additional tags to apply to Route53 resources"
  type        = map(string)
  default     = {}
}
