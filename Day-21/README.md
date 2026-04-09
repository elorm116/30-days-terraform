# Day 21 — Workflow for Deploying Infrastructure Code

Date: 2026-04-09

## Repo layout (important)

- This repo uses “Day-*” folders for learning artifacts.
- For Day 21, the *documentation/labs* live in this folder (Day 21).
- The *deployable Terraform config for Day 21* lives here:
  - `Day-21/webserver-cluster/`
- That Day-21 folder is a copy of the Day-20 config and it targets the same Terraform Cloud workspace/state (see `backend.tf`).
- Important: don’t run Terraform from both Day-20 and Day-21 folders against the same Terraform Cloud workspace, or you’ll create “two sources of truth.” For Day 21, treat `Day-21/webserver-cluster/` as the canonical location.

## Chapter 10 (Terraform: Up & Running) — Notes

> NOTE: I can’t quote the book text here. Paste your notes/excerpts from the section “A Workflow for Deploying Infrastructure Code” and I’ll help map them precisely to the 7 steps and highlight every infra-specific divergence.

- Key takeaways:
  - 

## Step-by-step (7 steps)

### Step 1 — Version control
- Repo is in Git.
- Branch protection (GitHub):
  - Main requires 1+ approval
  - Status checks must pass
  - No direct pushes
- Evidence:
  - (Paste GitHub branch protection screenshots/notes)

### Step 2 — Run the code locally (plan)
Working directory used for Day 21 change:
- `Day-21/webserver-cluster`

Note on “terraform workspaces” vs Terraform Cloud workspaces:
- The book/workflow sometimes uses `terraform workspace select dev` for local/state-based workflows.
- In this repo, environment selection is handled by the Terraform Cloud workspace (`webserver-cluster-dev`) configured in `backend.tf`.

Commands:
- `terraform init`
- `terraform plan -out=day21.tfplan`

Terraform Cloud run:
- https://app.terraform.io/app/cradx/webserver-cluster-dev/runs/run-tDegMgxWS45FmkTi

Note:
- The plan output pasted below was generated earlier when the config still lived under Day-20.
- Re-run `terraform plan -out=day21.tfplan` from `Day-21/webserver-cluster/` and paste the new run link/output here to keep Day 21 fully self-contained.

Plan output (paste full output):

```text
Running plan in HCP Terraform. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

To view this run in a browser, visit:
https://app.terraform.io/app/cradx/webserver-cluster-dev/runs/run-tDegMgxWS45FmkTi

Waiting for the plan to start...

Terraform v1.14.7
on linux_amd64
Initializing plugins and modules...
module.webserver_cluster.data.aws_availability_zones.available: Refreshing...
module.webserver_cluster.data.aws_ami.amazon_linux: Refreshing...
module.webserver_cluster.data.aws_vpc.default: Refreshing...
module.webserver_cluster.data.aws_availability_zones.available: Refresh complete after 0s [id=us-east-1]
module.webserver_cluster.data.aws_vpc.default: Refresh complete after 1s [id=vpc-0b2535b0cec1f839c]
module.webserver_cluster.data.aws_subnets.default: Refreshing...
module.webserver_cluster.data.aws_subnets.default: Refresh complete after 0s [id=us-east-1]
module.webserver_cluster.data.aws_ami.amazon_linux: Refresh complete after 1s [id=ami-0c456f2cfcc96df82]

Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_cloudwatch_metric_alarm.day21_asg_cpu_high[0] will be created
  + resource "aws_cloudwatch_metric_alarm" "day21_asg_cpu_high" {
      + actions_enabled                       = true
      + alarm_actions                         = (sensitive value)
      + alarm_description                     = "Day 21: Average EC2 CPU across the ASG is above threshold."
      + alarm_name                            = "webservers-dev-dev-day21-asg-cpu-high"
      + arn                                   = (known after apply)
      + comparison_operator                   = "GreaterThanOrEqualToThreshold"
      + dimensions                            = (known after apply)
      + evaluate_low_sample_count_percentiles = (known after apply)
      + evaluation_periods                    = 2
      + id                                    = (known after apply)
      + metric_name                           = "CPUUtilization"
      + namespace                             = "AWS/EC2"
      + ok_actions                            = (sensitive value)
      + period                                = 60
      + region                                = "us-east-1"
      + statistic                             = "Average"
      + tags_all                              = (known after apply)
      + threshold                             = 75
      + treat_missing_data                    = "notBreaching"
    }

  # aws_sns_topic.day21_alarms[0] will be created
  + resource "aws_sns_topic" "day21_alarms" {
      + arn                         = (known after apply)
      + beginning_archive_time      = (known after apply)
      + content_based_deduplication = false
      + fifo_throughput_scope       = (known after apply)
      + fifo_topic                  = false
      + id                          = (known after apply)
      + name                        = "webservers-dev-dev-day21-alarms"
      + name_prefix                 = (known after apply)
      + owner                       = (known after apply)
      + policy                      = (known after apply)
      + region                      = "us-east-1"
      + signature_version           = (known after apply)
      + tags_all                    = (known after apply)
      + tracing_config              = (known after apply)
    }

  # aws_sns_topic_subscription.day21_alarm_email[0] will be created
  + resource "aws_sns_topic_subscription" "day21_alarm_email" {
      + arn                             = (known after apply)
      + confirmation_timeout_in_minutes = 1
      + confirmation_was_authenticated  = (known after apply)
      + endpoint                        = (sensitive value)
      + endpoint_auto_confirms          = false
      + filter_policy_scope             = (known after apply)
      + id                              = (known after apply)
      + owner_id                        = (known after apply)
      + pending_confirmation            = (known after apply)
      + protocol                        = "email"
      + raw_message_delivery            = false
      + region                          = "us-east-1"
      + topic_arn                       = (known after apply)
    }

  # module.webserver_cluster.aws_autoscaling_group.web will be created
  + resource "aws_autoscaling_group" "web" {
      + arn                              = (known after apply)
      + availability_zones               = (known after apply)
      + default_cooldown                 = (known after apply)
      + desired_capacity                 = 3
      + force_delete                     = false
      + force_delete_warm_pool           = false
      + health_check_grace_period        = 300
      + health_check_type                = "ELB"
      + id                               = (known after apply)
      + ignore_failed_scaling_activities = false
      + load_balancers                   = (known after apply)
      + max_size                         = 10
      + metrics_granularity              = "1Minute"
      + min_size                         = 3
      + name                             = (known after apply)
      + name_prefix                      = "webservers-dev-asg-"
      + predicted_capacity               = (known after apply)
      + protect_from_scale_in            = false
      + region                           = "us-east-1"
      + service_linked_role_arn          = (known after apply)
      + target_group_arns                = (known after apply)
      + vpc_zone_identifier              = [
          + "subnet-02c7eb3a92535de58",
          + "subnet-0429b98bccbc17743",
          + "subnet-08d2aea31fbbf67ad",
          + "subnet-0b217813cea01f094",
          + "subnet-0c2ac1a76e47dcc4c",
        ]
      + wait_for_capacity_timeout        = "10m"
      + warm_pool_size                   = (known after apply)

      + availability_zone_distribution (known after apply)

      + capacity_reservation_specification (known after apply)

      + launch_template {
          + id      = (known after apply)
          + name    = (known after apply)
          + version = "$Latest"
        }

      + mixed_instances_policy (known after apply)

      + tag {
          + key                 = "Environment"
          + propagate_at_launch = true
          + value               = "dev"
        }
      + tag {
          + key                 = "ManagedBy"
          + propagate_at_launch = true
          + value               = "Terraform"
        }
      + tag {
          + key                 = "Name"
          + propagate_at_launch = true
          + value               = "webservers-dev-asg"
        }
      + tag {
          + key                 = "Project"
          + propagate_at_launch = true
          + value               = "terraform-webserver"
        }
      + tag {
          + key                 = "Team"
          + propagate_at_launch = true
          + value               = "devops"
        }
      + tag {
          + key                 = "Terraform"
          + propagate_at_launch = true
          + value               = "true"
        }

      + traffic_source (known after apply)
    }

  # module.webserver_cluster.aws_cloudwatch_log_group.web will be created
  + resource "aws_cloudwatch_log_group" "web" {
      + arn                         = (known after apply)
      + deletion_protection_enabled = (known after apply)
      + id                          = (known after apply)
      + log_group_class             = (known after apply)
      + name                        = "/aws/ec2/webservers-dev"
      + name_prefix                 = (known after apply)
      + region                      = "us-east-1"
      + retention_in_days           = 30
      + skip_destroy                = false
      + tags                        = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + tags_all                    = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
    }

  # module.webserver_cluster.aws_launch_template.web will be created
  + resource "aws_launch_template" "web" {
      + arn                    = (known after apply)
      + default_version        = (known after apply)
      + id                     = (known after apply)
      + image_id               = "ami-0c456f2cfcc96df82"
      + instance_type          = "t3.micro"
      + latest_version         = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "webservers-dev-lt-"
      + region                 = "us-east-1"
      + tags_all               = (known after apply)
      + user_data              = "IyEvYmluL2Jhc2gKZG5mIGluc3RhbGwgLXkgaHR0cGQKc2VkIC1pICdzL15MaXN0ZW4gODAkL0xpc3RlbiA4MDgwLycgL2V0Yy9odHRwZC9jb25mL2h0dHBkLmNvbmYKc3lzdGVtY3RsIGVuYWJsZSAtLW5vdyBodHRwZAplY2hvICI8aDE+d2Vic2VydmVycy1kZXYg4oCUIERldmVsb3BtZW50IHYzIPCfmoA8L2gxPiIgPiAvdmFyL3d3dy9odG1sL2luZGV4Lmh0bWwK"
      + vpc_security_group_ids = (known after apply)

      + metadata_options (known after apply)

      + tag_specifications {
          + resource_type = "instance"
          + tags          = {
              + "Environment" = "dev"
              + "ManagedBy"   = "Terraform"
              + "Name"        = "webservers-dev-instance"
              + "Project"     = "terraform-webserver"
              + "Team"        = "devops"
              + "Terraform"   = "true"
              + "Version"     = "Development v3"
            }
        }
    }

  # module.webserver_cluster.aws_lb.web will be created
  + resource "aws_lb" "web" {
      + arn                                                          = (known after apply)
      + arn_suffix                                                   = (known after apply)
      + client_keep_alive                                            = 3600
      + desync_mitigation_mode                                       = "defensive"
      + dns_name                                                     = (known after apply)
      + drop_invalid_header_fields                                   = false
      + enable_deletion_protection                                   = false
      + enable_http2                                                 = true
      + enable_tls_version_and_cipher_suite_headers                  = false
      + enable_waf_fail_open                                         = false
      + enable_xff_client_port                                       = false
      + enable_zonal_shift                                           = false
      + enforce_security_group_inbound_rules_on_private_link_traffic = (known after apply)
      + id                                                           = (known after apply)
      + idle_timeout                                                 = 60
      + internal                                                     = false
      + ip_address_type                                              = (known after apply)
      + load_balancer_type                                           = "application"
      + name                                                         = "webservers-dev-alb"
      + name_prefix                                                  = (known after apply)
      + preserve_host_header                                         = false
      + region                                                       = "us-east-1"
      + secondary_ips_auto_assigned_per_subnet                       = (known after apply)
      + security_groups                                              = (known after apply)
      + subnets                                                      = [
          + "subnet-02c7eb3a92535de58",
          + "subnet-0429b98bccbc17743",
          + "subnet-08d2aea31fbbf67ad",
          + "subnet-0b217813cea01f094",
          + "subnet-0c2ac1a76e47dcc4c",
        ]
      + tags                                                         = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + tags_all                                                     = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + vpc_id                                                       = (known after apply)
      + xff_header_processing_mode                                   = "append"
      + zone_id                                                      = (known after apply)

      + subnet_mapping (known after apply)
    }

  # module.webserver_cluster.aws_lb_listener.http will be created
  + resource "aws_lb_listener" "http" {
      + arn                                                                   = (known after apply)
      + id                                                                    = (known after apply)
      + load_balancer_arn                                                     = (known after apply)
      + port                                                                  = 80
      + protocol                                                              = "HTTP"
      + region                                                                = "us-east-1"
      + routing_http_request_x_amzn_mtls_clientcert_header_name               = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_issuer_header_name        = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_leaf_header_name          = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_serial_number_header_name = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_subject_header_name       = (known after apply)
      + routing_http_request_x_amzn_mtls_clientcert_validity_header_name      = (known after apply)
      + routing_http_request_x_amzn_tls_cipher_suite_header_name              = (known after apply)
      + routing_http_request_x_amzn_tls_version_header_name                   = (known after apply)
      + routing_http_response_access_control_allow_credentials_header_value   = (known after apply)
      + routing_http_response_access_control_allow_headers_header_value       = (known after apply)
      + routing_http_response_access_control_allow_methods_header_value       = (known after apply)
      + routing_http_response_access_control_allow_origin_header_value        = (known after apply)
      + routing_http_response_access_control_expose_headers_header_value      = (known after apply)
      + routing_http_response_access_control_max_age_header_value             = (known after apply)
      + routing_http_response_content_security_policy_header_value            = (known after apply)
      + routing_http_response_server_enabled                                  = (known after apply)
      + routing_http_response_strict_transport_security_header_value          = (known after apply)
      + routing_http_response_x_content_type_options_header_value             = (known after apply)
      + routing_http_response_x_frame_options_header_value                    = (known after apply)
      + ssl_policy                                                            = (known after apply)
      + tags_all                                                              = (known after apply)
      + tcp_idle_timeout_seconds                                              = (known after apply)

      + default_action {
          + order = (known after apply)
          + type  = "fixed-response"

          + fixed_response {
              + content_type = "text/plain"
              + message_body = "404: page not found"
              + status_code  = "404"
            }
        }

      + mutual_authentication (known after apply)
    }

  # module.webserver_cluster.aws_lb_listener_rule.web will be created
  + resource "aws_lb_listener_rule" "web" {
      + arn          = (known after apply)
      + id           = (known after apply)
      + listener_arn = (known after apply)
      + priority     = 100
      + region       = "us-east-1"
      + tags_all     = (known after apply)

      + action {
          + order            = (known after apply)
          + target_group_arn = (known after apply)
          + type             = "forward"
        }

      + condition {
          + path_pattern {
              + regex_values = []
              + values       = [
                  + "/*",
                ]
            }
        }
    }

  # module.webserver_cluster.aws_lb_target_group.web will be created
  + resource "aws_lb_target_group" "web" {
      + arn                                = (known after apply)
      + arn_suffix                         = (known after apply)
      + connection_termination             = (known after apply)
      + deregistration_delay               = "300"
      + id                                 = (known after apply)
      + ip_address_type                    = (known after apply)
      + lambda_multi_value_headers_enabled = false
      + load_balancer_arns                 = (known after apply)
      + load_balancing_algorithm_type      = (known after apply)
      + load_balancing_anomaly_mitigation  = (known after apply)
      + load_balancing_cross_zone_enabled  = (known after apply)
      + name                               = "webservers-dev-tg"
      + name_prefix                        = (known after apply)
      + port                               = 8080
      + preserve_client_ip                 = (known after apply)
      + protocol                           = "HTTP"
      + protocol_version                   = (known after apply)
      + proxy_protocol_v2                  = false
      + region                             = "us-east-1"
      + slow_start                         = 0
      + tags                               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + tags_all                           = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + target_type                        = "instance"
      + vpc_id                             = "vpc-0b2535b0cec1f839c"

      + health_check {
          + enabled             = true
          + healthy_threshold   = 2
          + interval            = 15
          + matcher             = "200"
          + path                = "/"
          + port                = "traffic-port"
          + protocol            = "HTTP"
          + timeout             = 5
          + unhealthy_threshold = 2
        }

      + stickiness (known after apply)

      + target_failover (known after apply)

      + target_group_health (known after apply)

      + target_health_state (known after apply)
    }

  # module.webserver_cluster.aws_security_group.alb_sg will be created
  + resource "aws_security_group" "alb_sg" {
      + arn                    = (known after apply)
      + description            = "Managed by Terraform"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
                # (1 unchanged attribute hidden)
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + from_port        = 80
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = []
              + self             = false
              + to_port          = 80
                # (1 unchanged attribute hidden)
            },
        ]
      + name                   = "webservers-dev-alb-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-east-1"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "webservers-dev-alb-sg"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "webservers-dev-alb-sg"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + vpc_id                 = "vpc-0b2535b0cec1f839c"
    }

  # module.webserver_cluster.aws_security_group.web_sg will be created
  + resource "aws_security_group" "web_sg" {
      + arn                    = (known after apply)
      + description            = "Managed by Terraform"
      + egress                 = [
          + {
              + cidr_blocks      = [
                  + "0.0.0.0/0",
                ]
              + from_port        = 0
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "-1"
              + security_groups  = []
              + self             = false
              + to_port          = 0
                # (1 unchanged attribute hidden)
            },
        ]
      + id                     = (known after apply)
      + ingress                = [
          + {
              + cidr_blocks      = []
              + from_port        = 8080
              + ipv6_cidr_blocks = []
              + prefix_list_ids  = []
              + protocol         = "tcp"
              + security_groups  = (known after apply)
              + self             = false
              + to_port          = 8080
                # (1 unchanged attribute hidden)
            },
        ]
      + name                   = "webservers-dev-web-sg"
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-east-1"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "webservers-dev-web-sg"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + tags_all               = {
          + "Environment" = "dev"
          + "ManagedBy"   = "Terraform"
          + "Name"        = "webservers-dev-web-sg"
          + "Project"     = "terraform-webserver"
          + "Team"        = "devops"
          + "Terraform"   = "true"
        }
      + vpc_id                 = "vpc-0b2535b0cec1f839c"
    }

Plan: 12 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_arn                = (known after apply)
  + alb_dns_name           = (known after apply)
  + asg_name               = (known after apply)
  + cluster_name           = "webservers-dev"
  + cluster_sizing         = "Min: 3, Max: 10"
  + day21_alarm_topic_arn  = (known after apply)
  + day21_cpu_alarm_arn    = (known after apply)
  + environment            = "dev"
  + instance_type_deployed = "t3.micro"
  + target_group_arn       = (known after apply)

───────────────────────────────────────────────────────────────────────────────

Saved the plan to: day21.tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply "day21.tfplan"
```

Resources affected:
- Created: 12
- Modified: 0
- Destroyed: 0

### Step 3 — Make code changes
Feature branch:
- `add-cloudwatch-alarms-day21`

Change implemented:
- Added an extra CloudWatch CPU alarm for the ASG (root module) and optional SNS email notifications.

Files changed:
- `Day-20/webserver-cluster/day21-alarms.tf`
- `Day-20/webserver-cluster/outputs.tf`

### Step 4 — Submit for review (PR)
PR description used:

## What this changes
Adds a Day-21 CloudWatch CPU alarm for the webserver cluster ASG (and an SNS topic + email subscription when `alarm_email` is set), so high CPU is detectable without reading dashboards.

## Terraform plan output
```text
(Full plan output pasted in the PR description was the exact same output as in Step 2 above.)
```

## Resources affected
- Created: 12
- Modified: 0
- Destroyed: 0

## Blast radius
- If the apply fails midway, the worst case is partial monitoring setup (alarm/topic/subscription). The cluster serving traffic should continue running.
- Potential operational impact: duplicate alerts if the upstream module already provisions alarms.

## Rollback plan
- Revert the PR and apply again.
- Or: `terraform destroy -target=aws_cloudwatch_metric_alarm.day21_asg_cpu_high` (and SNS resources) if you need to remove only the Day-21 additions.

### Step 5 — Run automated tests
Expected CI checks on PR:
- `terraform fmt -check`
- `terraform validate`
- `terraform test` (where applicable)

Evidence:
- (Link to Actions run)

### Step 6 — Merge and release
- Merge PR after approval + green checks.
- Tag release (if this is a reusable module):
  - `git tag -a "vX.Y.Z" -m "Day 21: Add CPU alarm"`
  - `git push origin vX.Y.Z`

### Step 7 — Deploy
Deploy method:
- Terraform Cloud: Apply the reviewed run (pins the exact plan that was reviewed).
- Local plan file pinning (if using local execution):
  - `terraform plan -out=day21.tfplan`
  - `terraform apply day21.tfplan`

Verification:
- Confirm alarm exists in CloudWatch.
- Run `terraform plan` again and confirm it’s clean.

Paste apply confirmation / verification notes:

```text
PASTE_APPLY_CONFIRMATION_HERE
```

## Infrastructure-specific safeguards implemented

1) Approval gates for destructive changes
- Terraform Cloud: require an explicit apply approval step for any run.
- Extra rule: if plan shows any destroys, require a second approval (separate from PR review).
- Evidence:
  - (Paste screenshot/notes of TFC apply approval settings)

2) Plan pinning
- Applied the exact reviewed plan (Terraform Cloud run) OR applied from `day21.tfplan`.
- Evidence:
  - (Paste commands or TFC run link)

3) State backup before apply
- S3 state bucket versioning enabled (if using S3 backend) and restore process understood.
- Evidence:
  - (Paste `aws s3api list-object-versions ...` output)

4) Blast radius documentation
- Included Blast radius + Rollback plan in PR description.

## Sentinel policy

Policy file:
- `Day-21/sentinel/require-instance-type.sentinel`

Policy contents:
```sentinel
import "tfplan/v2" as tfplan

allowed_instance_types = ["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is not "aws_instance" or
    rc.change.after.instance_type in allowed_instance_types
  }
}
```

What it enforces (plain English):
- Blocks any plan that tries to create/modify an `aws_instance` to use an instance type outside the allowlist.

How it differs from `terraform validate`:
- `terraform validate` checks syntax and internal references.
- Sentinel evaluates the *intent of the plan* against organization rules (policy-as-code), and can block applies.

## Infrastructure vs application workflow — key differences

1) State and drift
- Infra deploys are diffs against a state file; drift can change what a deploy will do.

2) Blast radius
- Infra changes can destroy shared dependencies (VPC/IAM/DB), not just break one endpoint.

3) Stronger approval + pinning
- You must pin what gets applied to what was reviewed (plan/run) and add explicit approval gates, especially for destroys.

## “Most dangerous step” (from Chapter 10)
- (Fill from the book section)

## Challenges and fixes
- (Fill: any issues with plan pinning, Sentinel, approvals, etc.)

## Blog post
- URL: 
- Summary:

## Social media
- URL:
