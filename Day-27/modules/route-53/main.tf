# Route53 is a global service — resources are not region-specific.
# No provider alias is needed: this module uses whichever provider is configured
# in the calling configuration. Health checks and DNS records are all global.

# ── Health Check — Primary Region ─────────────────────────────────────────────
# Route53 health checkers (spread across multiple AWS locations globally) send
# HTTP GET requests to the primary ALB's /health endpoint every 30 seconds.
# After failure_threshold consecutive failures, the primary record is marked
# unhealthy and Route53 stops returning it in DNS responses.
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.37"
    }
  }
}

resource "aws_route53_health_check" "primary" {
  fqdn              = var.primary_alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = var.health_check_failure_threshold
  request_interval  = var.health_check_request_interval

  # CloudWatch integration: publish health check state as a metric.
  # Enables alarming when the primary region is unhealthy.
  enable_sni                      = false
  measure_latency                 = true
  cloudwatch_alarm_region         = var.primary_region

  tags = merge(var.tags, {
    Name        = "hc-primary-${var.primary_region}"
    Region      = var.primary_region
    Role        = "primary"
    ManagedBy   = "terraform"
  })
}

# ── Health Check — Secondary Region ───────────────────────────────────────────
resource "aws_route53_health_check" "secondary" {
  fqdn              = var.secondary_alb_dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = var.health_check_failure_threshold
  request_interval  = var.health_check_request_interval

  enable_sni      = false
  measure_latency = true
  cloudwatch_alarm_region = var.secondary_region

  tags = merge(var.tags, {
    Name        = "hc-secondary-${var.secondary_region}"
    Region      = var.secondary_region
    Role        = "secondary"
    ManagedBy   = "terraform"
  })
}

# ── DNS Failover Record — PRIMARY ─────────────────────────────────────────────
# Under normal conditions, Route53 returns this record (us-east-1 ALB).
# When health_check_id fails, Route53 automatically stops returning this record
# and falls back to the SECONDARY record.
#
# Failover mechanism:
# 1. Route53 health checkers detect the primary ALB is unhealthy
# 2. After failure_threshold failures, primary is marked UNHEALTHY
# 3. Route53 stops returning the PRIMARY A record in responses
# 4. All DNS queries return the SECONDARY record (us-west-2 ALB)
# 5. DNS TTL expires on cached responses (~60 seconds for ALB alias records)
# 6. Clients reconnect to the secondary region
resource "aws_route53_record" "primary" {
  zone_id        = var.hosted_zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "primary-${var.primary_region}"
  health_check_id = aws_route53_health_check.primary.id

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = var.primary_alb_dns_name
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
    # evaluate_target_health = true: Route53 also considers the ALB's own
    # health when deciding whether to return this record. Double protection:
    # both the Route53 health check AND the ALB's internal health must be
    # passing for the PRIMARY record to be returned.
  }
}

# ── DNS Failover Record — SECONDARY ───────────────────────────────────────────
# Route53 returns this record ONLY when the PRIMARY is unhealthy.
# The secondary record does not need its own health check to activate —
# Route53 automatically falls back to it when primary fails.
# We attach a health check anyway to ensure Route53 has visibility into
# secondary health and doesn't fail over to a broken secondary.
resource "aws_route53_record" "secondary" {
  zone_id        = var.hosted_zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "secondary-${var.secondary_region}"
  health_check_id = aws_route53_health_check.secondary.id

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.secondary_alb_dns_name
    zone_id                = var.secondary_alb_zone_id
    evaluate_target_health = true
  }
}

# ── CloudWatch Alarm — Primary Health Check ────────────────────────────────────
# Alerts when the primary region health check fails — before users are affected.
# Wire this to SNS → PagerDuty or Slack for incident notification.
resource "aws_cloudwatch_metric_alarm" "primary_health" {
  alarm_name          = "route53-primary-unhealthy-${var.primary_region}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  alarm_description = "Primary region (${var.primary_region}) Route53 health check failing — DNS failover to ${var.secondary_region} is active or imminent"

  tags = merge(var.tags, {
    Name      = "route53-primary-health-alarm"
    ManagedBy = "terraform"
  })
}
