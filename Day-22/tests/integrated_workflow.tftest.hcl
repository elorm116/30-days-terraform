# tests/integrated_workflow.tftest.hcl
# terraform test — Day 22 integrated workflow validation
#
# These tests validate the complete integrated stack:
# tagging compliance, security configuration, alarm thresholds,
# and variable validation guards.

# ── Test 1: All resources carry the ManagedBy = Terraform tag ────────────────
# This mirrors the Sentinel policy — catching tag violations at test time
# means faster feedback than waiting for Sentinel to block in Terraform Cloud.
run "all_resources_carry_managed_by_tag" {
  command = plan

  variables {
    cluster_name             = "test-cluster"
    instance_type            = "t3.micro"
    server_port              = 8080
    min_size                 = 2
    max_size                 = 4
    desired_capacity         = 2
    cpu_alarm_threshold_high = 80
    alert_emails             = []
  }

  # The provider default_tags block sets ManagedBy = "Terraform" universally.
  # Verify the launch template propagates it to instances.
  assert {
    condition     = contains(keys(aws_launch_template.webserver.tag_specifications[0].tags), "ManagedBy")
    error_message = "Launch template must propagate ManagedBy tag to instances"
  }

  assert {
    condition     = aws_launch_template.webserver.tag_specifications[0].tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy tag value must be 'Terraform' (case-sensitive — Sentinel enforces exact match)"
  }
}

# ── Test 2: IMDSv2 is enforced on launch templates ───────────────────────────
# IMDSv2 (token-required) prevents SSRF attacks from reaching instance metadata.
# This is a security best practice — validates Day 22 security lab outcome.
run "imdsv2_enforced" {
  command = plan

  variables {
    cluster_name  = "test-cluster"
    instance_type = "t3.micro"
    server_port   = 8080
    min_size      = 2
    max_size      = 4
    alert_emails  = []
  }

  assert {
    condition     = aws_launch_template.webserver.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required (http_tokens = required) — IMDSv1 is a security risk"
  }

  assert {
    condition     = aws_launch_template.webserver.metadata_options[0].http_put_response_hop_limit == 1
    error_message = "Hop limit must be 1 to prevent container-to-metadata SSRF"
  }
}

# ── Test 3: ALB deletion protection in prod ───────────────────────────────────
run "alb_deletion_protection" {
  command = plan

  variables {
    cluster_name  = "test-cluster"
    instance_type = "t3.micro"
    server_port   = 8080
    min_size      = 2
    max_size      = 4
    alert_emails  = []
  }

  assert {
    condition     = aws_lb.webserver.enable_deletion_protection == (terraform.workspace == "prod")
    error_message = "ALB deletion protection must match workspace: enabled in prod, disabled elsewhere"
  }
}

# ── Test 4: S3 bucket has public access blocked ───────────────────────────────
run "s3_public_access_blocked" {
  command = plan

  variables {
    cluster_name  = "test-cluster"
    instance_type = "t3.micro"
    server_port   = 8080
    min_size      = 2
    max_size      = 4
    alert_emails  = []
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.alb_logs.block_public_acls == true
    error_message = "S3 log bucket must block public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.alb_logs.restrict_public_buckets == true
    error_message = "S3 log bucket must restrict public bucket policies"
  }
}

# ── Test 5: CloudWatch alarm thresholds within safe ranges ────────────────────
run "alarm_thresholds_sane" {
  command = plan

  variables {
    cluster_name             = "test-cluster"
    instance_type            = "t3.micro"
    server_port              = 8080
    min_size                 = 2
    max_size                 = 4
    cpu_alarm_threshold_high = 80
    alert_emails             = []
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.threshold == 80
    error_message = "CPU high alarm threshold must match variable"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high.evaluation_periods >= 2
    error_message = "CPU alarm needs >= 2 evaluation periods to avoid flapping on transient spikes"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.unhealthy_hosts.threshold == 0
    error_message = "Unhealthy host alarm must fire on ANY unhealthy host (threshold = 0)"
  }
}

# ── Test 6: Reject non-approved instance type (validation guard) ──────────────
run "reject_non_approved_instance_type" {
  command = plan

  variables {
    cluster_name  = "test-cluster"
    instance_type = "m5.large" # Not in approved list — should fail
    server_port   = 8080
    min_size      = 2
    max_size      = 4
    alert_emails  = []
  }

  expect_failures = [var.instance_type]
}

# ── Test 7: Reject privileged port ───────────────────────────────────────────
run "reject_privileged_port" {
  command = plan

  variables {
    cluster_name  = "test-cluster"
    instance_type = "t3.micro"
    server_port   = 443 # Privileged — should fail validation
    min_size      = 2
    max_size      = 4
    alert_emails  = []
  }

  expect_failures = [var.server_port]
}

# ── Test 8: min_size >= 2 for HA ──────────────────────────────────────────────
run "reject_single_instance_cluster" {
  command = plan

  variables {
    cluster_name  = "test-cluster"
    instance_type = "t3.micro"
    server_port   = 8080
    min_size      = 1 # Below HA minimum
    max_size      = 4
    alert_emails  = []
  }

  expect_failures = [var.min_size]
}
