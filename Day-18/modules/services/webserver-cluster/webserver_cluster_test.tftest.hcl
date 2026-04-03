# Native Terraform unit tests — no real infrastructure deployed.
# command = plan means Terraform generates a plan but never calls AWS APIs.
# Tests run in seconds and are completely free.
#
# These tests answer: "Does the configuration INTEND to do the right thing?"
# Integration tests answer: "Does it ACTUALLY do the right thing when deployed?"


# Mock the AWS provider so unit tests don't need real AWS credentials.
# Mocks return synthetic data for data sources — no real API calls made.
mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-12345678"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id         = "vpc-12345678"
      cidr_block = "10.0.0.0/16"
    }
  }

  mock_data "aws_subnets" {
    defaults = {
      ids = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az4"]
    }
  }

  # Override resource mocks to return valid AWS-format IDs
  # The mock provider generates random strings by default
  # but some resources validate format (ARNs must start with "arn:",
  # launch template IDs must start with "lt-")
  mock_resource "aws_lb" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/test-alb/1234567890abcdef"
      arn_suffix = "app/test-alb/1234567890abcdef"
      dns_name   = "test-alb-123456789.us-east-1.elb.amazonaws.com"
      zone_id    = "Z35SXDOTRQ7X7K"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id             = "lt-0123456789abcdef0"
      arn            = "arn:aws:ec2:us-east-1:123456789012:launch-template/lt-0123456789abcdef0"
      latest_version = 1
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/1234567890abcdef"
      arn_suffix = "targetgroup/test-tg/1234567890abcdef"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/test-alb/1234567890abcdef/1234567890abcdef"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:test-alerts"
    }
  }

  mock_resource "aws_autoscaling_policy" {
    defaults = {
      arn = "arn:aws:autoscaling:us-east-1:123456789012:scalingPolicy:test-policy"
    }
  }
}
# Variables used across all test runs
variables {
  cluster_name        = "test-cluster"
  instance_type       = "t3.micro"
  min_size            = 1
  max_size            = 2
  environment         = "dev"
  project_name        = "test-project"
  team_name           = "test-team"
  enable_monitoring   = false
  cpu_alarm_threshold = 80
  app_version         = "v1"
}

# -----------------------------
# RUN 1 — Validate ASG name prefix
# -----------------------------
# Why this matters: if cluster_name doesn't flow through to the ASG
# name_prefix, two deployments with different cluster names would
# create ASGs with identical names — AWS would reject the second one.
run "validate_asg_name_prefix" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = aws_autoscaling_group.web.name_prefix == "test-cluster-asg-"
    error_message = "ASG name_prefix must be <cluster_name>-asg- to ensure uniqueness per deployment"
  }
}

# -----------------------------
# RUN 2 — Validate instance type flows through
# -----------------------------
# Why this matters: if the launch template hardcoded an instance type
# instead of using var.instance_type, callers couldn't control sizing.
run "validate_launch_template_instance_type" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.micro"
    error_message = "Launch template instance type must match var.instance_type"
  }
}

# -----------------------------
# RUN 3 — Validate ALB security group allows port 80
# -----------------------------
# Why this matters: if the ALB SG doesn't allow port 80 from the internet
# the load balancer will never receive traffic — a silent failure.
run "validate_alb_sg_port" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition = anytrue([
      for rule in aws_security_group.alb_sg.ingress :
      rule.from_port == 80 &&
      rule.to_port == 80 &&
      rule.protocol == "tcp" &&
      contains(try(rule.cidr_blocks, []), "0.0.0.0/0")
    ])
    error_message = "ALB security group must allow inbound TCP traffic on port 80 from 0.0.0.0/0"
  }
}

# -----------------------------
# RUN 4 — Validate web SG uses server port
# -----------------------------
# Why this matters: if the web SG doesn't match the server_port variable
# the ALB health checks will fail — instances will never become healthy.
run "validate_web_sg_server_port" {
  # The `aws_security_group` resource returns ingress rules with values that may
  # only become fully known after apply (not during plan), especially when the
  # rule references another security group ID. Use a mocked apply in an
  # isolated state so this check remains deterministic and doesn't affect the
  # plan-only runs.
  command = apply

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition = anytrue([
      for rule in aws_security_group.web_sg.ingress :
      rule.from_port == 8080 &&
      rule.to_port == 8080 &&
      rule.protocol == "tcp" &&
      try(contains(rule.security_groups, aws_security_group.alb_sg.id), false)
    ])
    error_message = "Web security group must allow inbound TCP traffic on var.server_port (8080) from the ALB security group"
  }
}

# -----------------------------
# RUN 5 — Validate ELB health check type
# -----------------------------
# Why this matters: EC2 health checks only detect if the instance is running.
# ELB health checks detect if the app is responding. Without ELB health checks
# a crashed app stays in service and receives traffic — silent failure.
run "validate_elb_health_check_type" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = aws_autoscaling_group.web.health_check_type == "ELB"
    error_message = "ASG must use ELB health checks, not EC2 health checks"
  }
}

# -----------------------------
# RUN 6 — Validate dev environment gets correct instance type
# -----------------------------
# Why this matters: the locals block drives instance type from environment.
# This test verifies the locals logic works correctly for dev.
run "validate_dev_instance_type_from_locals" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.micro"
    error_message = "Dev environment must use t3.micro instance type from locals"
  }
}

# -----------------------------
# RUN 7 — Validate production environment gets larger instance type
# -----------------------------
# Overrides the top-level variables block for this specific run.
# Tests that the locals block correctly overrides instance type for production.
run "validate_production_instance_type_from_locals" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "production"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = aws_launch_template.web.instance_type == "t3.small"
    error_message = "Production environment must use t3.small instance type from locals"
  }
}

# -----------------------------
# RUN 8 — Validate log retention differs by environment
# -----------------------------
run "validate_dev_log_retention" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = aws_cloudwatch_log_group.web.retention_in_days == 7
    error_message = "Dev environment must have 7 day log retention"
  }
}

run "validate_production_log_retention" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "production"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = aws_cloudwatch_log_group.web.retention_in_days == 90
    error_message = "Production environment must have 90 day log retention"
  }
}

# -----------------------------
# RUN 9 — Validate monitoring resources not created when disabled
# -----------------------------
# Why this matters: count = var.enable_monitoring ? 1 : 0
# This test verifies the conditional resource pattern works correctly.
run "validate_monitoring_disabled" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = length(aws_sns_topic.alerts) == 0
    error_message = "SNS topic must not be created when enable_monitoring = false"
  }
}

# -----------------------------
# RUN 10 — Validate monitoring resources created when enabled
# -----------------------------
run "validate_monitoring_enabled" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "production"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = true
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  assert {
    condition     = length(aws_sns_topic.alerts) == 1
    error_message = "SNS topic must be created when enable_monitoring = true"
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.high_cpu) == 1
    error_message = "High CPU alarm must be created when enable_monitoring = true"
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.alb_5xx) == 1
    error_message = "ALB 5xx alarm must be created when enable_monitoring = true"
  }
}

# -----------------------------
# RUN 11 — Validate input validation rejects bad environment
# -----------------------------
# This test expects the plan to FAIL with a specific error.
# It verifies validation blocks work correctly.
run "validate_bad_environment_rejected" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "t3.micro"
    min_size            = 1
    max_size            = 2
    environment         = "prod"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  expect_failures = [
    var.environment,
  ]
}

# -----------------------------
# RUN 12 — Validate input validation rejects bad instance type
# -----------------------------
run "validate_bad_instance_type_rejected" {
  command = plan

  variables {
    cluster_name        = "test-cluster"
    instance_type       = "m5.xlarge"
    min_size            = 1
    max_size            = 2
    environment         = "dev"
    project_name        = "test-project"
    team_name           = "test-team"
    enable_monitoring   = false
    cpu_alarm_threshold = 80
    app_version         = "v1"
  }

  expect_failures = [
    var.instance_type,
  ]
}