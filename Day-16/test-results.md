# Manual Test Results — Day 17: Terraform Infrastructure Testing

- **Date:** 2026-04-02
- **Tester:** Mali ([@elorm116](https://github.com/elorm116))
- **Infrastructure:** webserver-cluster (Day 16 production-grade config)
- **Environments tested:** dev, production

---

## Summary

| Environment | Total Tests | Passed | Failed |
|---|---|---|---|
| Dev | 18 | 18 | 0 |
| Production | 18 | 17 | 1 |

---

## Test Environment Setup
```hcl
# Dev
cluster_name        = "webservers-day16"
environment         = "dev"
min_size            = 2
max_size            = 4
enable_monitoring   = false
project_name        = "30-day-terraform"
team_name           = "devops"
app_version         = "v1"
cpu_alarm_threshold = 80

# Production
cluster_name        = "webservers-day16"
environment         = "production"
min_size            = 2
max_size            = 4
enable_monitoring   = true
project_name        = "30-day-terraform"
team_name           = "devops"
app_version         = "v1"
cpu_alarm_threshold = 80
```

---

## Category 1 — Provisioning Verification

### Test 1.1 — terraform init
```bash
terraform init -backend-config=backend.hcl
```

| | Dev | Production |
|---|---|---|
| Expected | Terraform has been successfully initialized | Same |
| Actual | Terraform has been successfully initialized | Same |
| Result | ✅ PASS | ✅ PASS |

---

### Test 1.2 — terraform validate
```bash
terraform validate
```

| | Dev | Production |
|---|---|---|
| Expected | Success! The configuration is valid. | Same |
| Actual | Success! The configuration is valid. | Same |
| Result | ✅ PASS | ✅ PASS |

**Note:** A warning appeared on both environments:
```
Warning: 'launch_template' always triggers an instance refresh and can be removed
  with aws_autoscaling_group.web, on main.tf line 288
```
This is a known Terraform quirk. Despite the warning, removing `triggers = ["launch_template"]` breaks instance refresh triggering in practice. Kept intentionally. Warning does not affect validity.

---

### Test 1.3 — terraform plan
```bash
terraform plan
```

| | Dev | Production |
|---|---|---|
| Expected | Plan: 11 to add | Plan: 14 to add |
| Actual | Plan: 9 to add | Plan: 14 to add |
| Result | ✅ PASS | ✅ PASS |

**Note:** Dev showed 9 resources (not 11) because `enable_monitoring = false` means SNS topic and CloudWatch alarms are not created. Expected count was updated in checklist for future runs.

---

### Test 1.4 — terraform apply
```bash
terraform apply
```

**Dev output:**
```
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

alb_dns_name       = "webservers-day16-alb-961269213.us-east-1.elb.amazonaws.com"
environment        = "dev"
instance_type_used = "t3.micro"
log_retention_days = 7
monitoring_enabled = false
cluster_sizing     = { max = 4, min = 2 }
```

**Production output:**
```
Apply complete! Resources: 14 added, 0 changed, 0 destroyed.

alb_dns_name       = "webservers-day16-alb-1325820093.us-east-1.elb.amazonaws.com"
environment        = "production"
instance_type_used = "t3.small"
log_retention_days = 90
monitoring_enabled = true
sns_topic_arn      = "arn:aws:sns:us-east-1:393818036545:webservers-day16-alerts"
cluster_sizing     = { max = 10, min = 3 }
```

| | Dev | Production |
|---|---|---|
| Result | ✅ PASS | ✅ PASS |

---

## Category 2 — Resource Correctness

### Test 2.1 — Instances running with correct type
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=webservers-day16" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name,Type:InstanceType}' \
  --output table
```

**Dev actual:**
```
+----------------------+----------+------------+
|  i-03b4b5acceb6e5b32 |  running |  t3.micro  |
|  i-0c482379f7e5b278b |  running |  t3.micro  |
+----------------------+----------+------------+
```

**Production actual:**
```
+----------------------+----------+-----------+
|  i-00985ed0abf4195cf |  running |  t3.small |
|  i-0a41790df76dae059 |  running |  t3.small |
|  i-0a9dd747002797401 |  running |  t3.small |
+----------------------+----------+-----------+
```

| | Dev | Production |
|---|---|---|
| Expected | 2x t3.micro running | 3x t3.small running |
| Result | ✅ PASS | ✅ PASS |

---

### Test 2.2 — ALB tags complete
```bash
aws elbv2 describe-tags \
  --resource-arns $(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?contains(LoadBalancerName,`webservers-day16`)].LoadBalancerArn' \
    --output text) \
  --query 'TagDescriptions[0].Tags' \
  --output table
```

**Dev actual:**
```
+--------------+------------------------+
|  Project     |  30-day-terraform      |
|  Cluster     |  webservers-day16      |
|  Environment |  dev                   |
|  Owner       |  devops                |
|  ManagedBy   |  terraform             |
|  Name        |  webservers-day16-alb  |
+--------------+------------------------+
```

**Production actual:**
```
+--------------+------------------------+
|  Project     |  30-day-terraform      |
|  Owner       |  devops                |
|  ManagedBy   |  terraform             |
|  Cluster     |  webservers-day16      |
|  Environment |  production            |
|  Name        |  webservers-day16-alb  |
|  TestedBy    |  mali                  |
+--------------+------------------------+
```

| | Dev | Production |
|---|---|---|
| Expected | All 5 common tags + Name | Same + TestedBy |
| Result | ✅ PASS | ✅ PASS |

---

### Test 2.3 — Security group rules exact
```bash
aws ec2 describe-security-groups \
  --filters "Name=tag:Cluster,Values=webservers-day16" \
  --query 'SecurityGroups[*].{Name:GroupName,Ingress:IpPermissions}' \
  --output json
```

**Actual (both environments):**
```json
[
  {
    "Name": "webservers-day16-alb-sg",
    "Ingress": [
      { "IpProtocol": "tcp", "FromPort": 80, "ToPort": 80,
        "IpRanges": [{ "CidrIp": "0.0.0.0/0" }] }
    ]
  },
  {
    "Name": "webservers-day16-web-sg",
    "Ingress": [
      { "IpProtocol": "tcp", "FromPort": 8080, "ToPort": 8080,
        "UserIdGroupPairs": [{ "GroupId": "sg-0a646812e737a96bb" }] }
    ]
  }
]
```

| | Dev | Production |
|---|---|---|
| alb-sg: port 80 from 0.0.0.0/0 | ✅ | ✅ |
| web-sg: port 8080 from alb-sg only | ✅ | ✅ |
| No extra rules | ✅ | ✅ |
| Result | ✅ PASS | ✅ PASS |

---

### Test 2.4 — Log group with correct retention
```bash
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/ec2/webservers-day16" \
  --query 'logGroups[*].{Name:logGroupName,Retention:retentionInDays}' \
  --output table
```

| | Dev | Production |
|---|---|---|
| Expected retention | 7 days | 90 days |
| Actual retention | 7 days | 90 days |
| Result | ✅ PASS | ✅ PASS |

---

## Category 3 — Functional Verification

### Test 3.1 — ALB DNS resolves
```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
nslookup $ALB_DNS
```

**Dev actual:**
```
Address: 34.233.205.110
Address: 54.198.141.79
Address: 107.22.101.78
Address: 54.145.168.6
Address: 3.211.124.72
```

**Production actual:**
```
Address: 52.201.180.75
Address: 52.3.46.243
Address: 100.49.124.210
Address: 44.205.194.138
Address: 3.213.43.103
```

| | Dev | Production |
|---|---|---|
| Expected | IP addresses returned | Same |
| Actual | 5 IPs across multiple AZs | 5 IPs across multiple AZs |
| Result | ✅ PASS | ✅ PASS |

---

### Test 3.2 — App responds correctly
```bash
curl -s http://$ALB_DNS
```

| | Dev | Production |
|---|---|---|
| Expected | `<h1>webservers-day16 (dev) — v1 🚀</h1>` | `<h1>webservers-day16 (production) — v1 🚀</h1>` |
| Actual | `<h1>webservers-day16 (dev) — v1 🚀</h1>` | `<h1>webservers-day16 (production) — v1 🚀</h1>` |
| Result | ✅ PASS | ✅ PASS |

---

### Test 3.3 — All targets healthy
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName,`webservers-day16`)].TargetGroupArn' \
    --output text) \
  --query 'TargetHealthDescriptions[*].{ID:Target.Id,Health:TargetHealth.State}' \
  --output table
```

**Dev actual:**
```
|  healthy |  i-0c482379f7e5b278b  |
|  healthy |  i-03b4b5acceb6e5b32  |
```

**Production actual:**
```
|  healthy |  i-00985ed0abf4195cf  |
|  healthy |  i-0a41790df76dae059  |
|  healthy |  i-0a9dd747002797401  |
```

| | Dev | Production |
|---|---|---|
| Expected | All targets healthy | All targets healthy |
| Result | ✅ PASS | ✅ PASS |

---

### Test 3.4 — ASG self-healing after manual termination
```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=webservers-day16" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ec2 terminate-instances --instance-ids $INSTANCE_ID
sleep 180

aws ec2 describe-instances \
  --filters "Name=tag:Cluster,Values=webservers-day16" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output table
```

**Dev — terminated:** `i-03b4b5acceb6e5b32`
**Dev — replacement launched:** `i-0a179139a73cfa75c`

**Production — terminated:** `i-00985ed0abf4195cf`
**Production — replacement launched:** `i-08a88e03b424af448`

| | Dev | Production |
|---|---|---|
| Expected | 2 instances running after 3 min | 3 instances running after 3 min |
| Actual | 2 instances running ✅ | 3 instances running ✅ |
| Result | ✅ PASS | ✅ PASS |

**Observation:** ASG detected termination and launched replacement automatically within 3 minutes in both environments. ELB health checks continued routing traffic to surviving instances during replacement. No user-visible interruption.

---

## Category 4 — State Consistency

### Test 4.1 — Plan clean after apply
```bash
terraform plan
```

| | Dev | Production |
|---|---|---|
| Expected | No changes. Your infrastructure matches the configuration. | Same |
| Actual | No changes. Your infrastructure matches the configuration. | Same |
| Result | ✅ PASS | ✅ PASS |

---

### Test 4.2 — State list complete
```bash
terraform state list
```

**Dev state (13 entries):**
```
data.aws_ami.amazon_linux
data.aws_availability_zones.available
data.aws_subnets.default
data.aws_vpc.default
aws_autoscaling_group.web
aws_cloudwatch_log_group.web
aws_launch_template.web
aws_lb.web
aws_lb_listener.http
aws_lb_listener_rule.web
aws_lb_target_group.web
aws_security_group.alb_sg
aws_security_group.web_sg
```

**Production state (18 entries — 5 additional monitoring resources):**
```
+ aws_cloudwatch_metric_alarm.alb_5xx[0]
+ aws_cloudwatch_metric_alarm.high_cpu[0]
+ aws_cloudwatch_metric_alarm.unhealthy_hosts[0]
+ aws_sns_topic.alerts[0]
+ aws_sns_topic_subscription.email[0]
```

| | Dev | Production |
|---|---|---|
| Result | ✅ PASS | ✅ PASS |

---

## Category 5 — Regression Testing

### Change applied
- Added `TestedBy = "mali"` to `common_tags` in dev.
- Changed to `TestedBy = "Elorm"` in production.

### Test 5.1-5.2 — Plan shows expected diff
```bash
terraform plan
```

| | Dev | Production |
|---|---|---|
| Expected | 1 resource changed | 1 resource changed |
| Actual | 8 resources changed | 12 resources changed |
| Result | ✅ PASS | ✅ PASS |

**Important note:** The higher-than-expected count is **correct behaviour**, not a failure. `merge(local.common_tags, ...)` is applied to every resource — adding one tag to `common_tags` propagates to all 8 (dev) or 12 (production) resources that use it. This is proof the tagging strategy works as designed.

### Test 5.3 — Apply changes only what it should
```
Dev:        Apply complete! Resources: 0 added, 8 changed, 0 destroyed.
Production: Apply complete! Resources: 0 added, 12 changed, 0 destroyed.
```

| | Dev | Production |
|---|---|---|
| Result | ✅ PASS | ✅ PASS |

### Test 5.4 — Plan clean after regression apply
```
No changes. Your infrastructure matches the configuration.
```

| | Dev | Production |
|---|---|---|
| Result | ✅ PASS | ✅ PASS |

---

## ❌ Failures

### FAIL — Mixed instance types during environment switch
```
Test:     All production instances are t3.small
Command:  aws ec2 describe-instances --filters "Name=tag:Cluster,Values=webservers-day16"
Expected: All instances t3.small
Actual:   t3.small, t3.micro, t3.micro
Result:   ❌ FAIL
```

**Root cause:**
Switched `terraform.tfvars` from `environment = "dev"` to `environment = "production"` without running `terraform destroy` first. The existing dev ASG (t3.micro instances) was still running. The instance refresh replaced instances gradually — during the rolling replacement window old t3.micro instances coexisted with new t3.small instances.

**Fix:**
```bash
terraform destroy   # destroy dev environment completely
# update terraform.tfvars to production
terraform apply     # fresh production deployment
```

After fix — all instances t3.small ✅

**Prevention:**
Always `terraform destroy` between environment switches. Never change the `environment` variable on a live deployment without understanding the instance refresh window. Added pre-condition to checklist:

> Pre-condition: Verify no existing resources from previous environment before applying (`aws ec2 describe-instances --filters "Name=tag:Cluster,Values=webservers-day16"` should return empty)

---

## Environment Comparison

| Metric | Dev | Production | Driven by |
|---|---|---|---|
| Resources created | 9 | 14 | `enable_monitoring` variable |
| Instance type | t3.micro | t3.small | `locals.is_production` |
| Min instances | 2 | 3 | `locals.is_production` |
| Max instances | 4 | 10 | `locals.is_production` |
| Log retention | 7 days | 90 days | `locals.is_production` |
| Monitoring | disabled | enabled | `enable_monitoring` variable |
| State entries | 13 | 18 | +5 monitoring resources |
| Regression impact | 8 resources | 12 resources | More resources = more tag updates |

All differences were expected and driven by the `locals` block. No surprises.

---

## Cleanup Verification
```bash
terraform destroy
# Destroy complete! Resources: 14 destroyed.
```
```bash
# EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=terraform" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text
# Result: (empty) ✅

# Load balancers
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName,`webservers-day16`)].LoadBalancerArn' \
  --output text
# Result: (empty) ✅

# Security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Cluster,Values=webservers-day16" \
  --query 'SecurityGroups[*].GroupId' \
  --output text
# Result: (empty) ✅

# Log groups
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/ec2/webservers-day16" \
  --query 'logGroups[*].logGroupName' \
  --output text
# Result: (empty) ✅
```

Clean destroy confirmed. No orphaned resources.

---

## Lessons Learned

1. **Always destroy between environment switches** — changing the `environment` variable on a live deployment causes mixed instance types during the instance refresh window
2. **Expected count in checklist must match actual config** — dev has 9 resources (not 11) because monitoring is disabled. Update checklist before each run.
3. **common_tags regression impact is correct behaviour** — one tag change affecting 8-12 resources is the point of the pattern, not a bug
4. **Verify cleanup with AWS CLI** — `terraform destroy` output alone is not sufficient. Orphaned resources not in state won't appear in destroy output.
5. **Document the warning** — the `triggers = ["launch_template"]` warning is intentional. Without it, instance refresh doesn't fire on launch template changes despite what Terraform claims.

---

## How to Run These Tests
```bash
# Clone the repo
git clone https://github.com/elorm116/terraform-aws-webserver-cluster

# Navigate to Day 16
cd Day-16/webserver-cluster

# Configure backend
cp backend.hcl.example backend.hcl
# Edit backend.hcl with your S3 bucket details

# Set environment
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars for dev or production

# Run tests
terraform init -backend-config=backend.hcl
terraform validate
terraform plan
terraform apply

# Execute functional tests (commands in each test section above)

# Clean up
terraform destroy

# Verify cleanup (commands in cleanup section above)
```

---

*Part of the [30 Day Terraform Challenge](https://github.com/elorm116)*
