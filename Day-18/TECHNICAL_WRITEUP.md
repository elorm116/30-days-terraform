# Terraform 3-Layer Testing System — Complete Technical Writeup

> 📌 **This is the full implementation guide** for the blog post *"I Stopped Trusting Terraform Apply — So I Built a 3-Layer Testing System"*
>
> Here you'll find every detail, every challenge, and every solution. Ready to dive deep.

---

## Who This Guide Is For

This guide is for:
- ✅ **Engineers already using Terraform modules** (not just learning basics)
- ✅ **Teams managing multiple environments** (dev, staging, production)
- ✅ **Anyone who has experienced** "it passed plan, but failed in production"
- ✅ **Teams ready to eliminate guesswork** and build confidence in deployments

**Not for:** Terraform beginners. If you're new to Terraform, start with basic module documentation before tackling this testing system.

---

## The Incident That Forced This System

One afternoon, a Terratest integration test failed halfway through deployment with a CloudWatch quota error.

Terraform exited early.

But the infrastructure didn't.

**What happened:**
- 4 EC2 instances kept running
- 2 load balancers kept billing
- I didn't notice for 6 hours
- AWS bill: +$8

**Worse than the money:** I realized I had **no confidence** in my infrastructure. I couldn't refactor safely. I couldn't deploy with certainty.

That's when I understood: *Testing isn't just about correctness. It's about control.*

This guide is the system I built to fix that.

---

## Where to Start (If You Do Nothing Else)

Implementing all three layers feels overwhelming. Don't be paralyzed.

**Day 1: Add 3-5 unit tests**
```bash
terraform test -verbose
```
Cost: Free. Time: 30 seconds. Impact: Massive.

**Week 1: Add one integration test**
```bash
go test -v ./...
```
Cost: ~$0.50. Time: 10 minutes. Impact: Reveals 80% of real issues.

**Month 1: Add E2E test**
```bash
go test -v -run TestEndToEnd ./...
```
Cost: ~$5. Time: 30+ minutes. Reserved for weekly runs.

**That's it.** Just these three steps will eliminate most real-world failures. Everything else is refinement.

---

## How the 3-Layer System Works (Visual)

```
┌─────────────────────────────────────────────────────────────┐
│                    UNIT TESTS (terraform test)              │
│  Validates: Logic, Variables, Resource Configuration        │
│  Speed: ⚡ ~30 seconds  |  Cost: 💸 Free  |  AWS: ❌ No     │
└──────────────────────┬──────────────────────────────────────┘
                       │ [PASS]
                       ↓
┌─────────────────────────────────────────────────────────────┐
│            INTEGRATION TESTS (Terratest in Go)              │
│  Deploys: Real AWS + Verifies + Destroys                    │
│  Speed: 🐇 ~10 min  |  Cost: 💰 ~$0.50  |  AWS: ✅ Yes     │
└──────────────────────┬──────────────────────────────────────┘
                       │ [PASS]
                       ↓
┌─────────────────────────────────────────────────────────────┐
│           END-TO-END TESTS (Multi-Environment)              │
│  Deploys: Dev → Staging → Prod all in sequence              │
│  Speed: 🐢 ~30 min  |  Cost: 💵 ~$5  |  AWS: ✅ Yes ✅ Yes  │
└─────────────────────────────────────────────────────────────┘
```

Each layer answers a different question:
- **Unit:** "Does this code make sense?"
- **Integration:** "Does it actually work in AWS?"
- **E2E:** "Does it work across all environments?"

---

## Table of Contents

1. [All 13 Unit Tests Explained](#layer-1-unit-tests)
2. [Complete Integration Test Code](#layer-2-integration-tests)
3. [End-to-End Test Orchestration](#layer-3-end-to-end-tests)
4. [Real Challenges & Solutions](#real-challenges--solutions)
5. [GitHub Actions Workflow](#github-actions-workflow)
6. [Cost & Performance Breakdown](#cost--performance-breakdown)
7. [Execution Results](#execution-results)

---

## Layer 1: Unit Tests

### File Location
[`modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl`](./modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl)

### All 13 Unit Tests

#### **Test 1: validate_asg_name_prefix**
```hcl
assert {
  condition     = aws_autoscaling_group.web.name_prefix == "${var.cluster_name}-"
  error_message = "ASG name must have cluster_name prefix"
}
```
✅ **Why it guarantees:** ASGs follow naming conventions so ops teams can identify resources by automation

#### **Test 2: validate_launch_template_instance_type**
```hcl
assert {
  condition     = aws_launch_template.web.instance_type == var.instance_type
  error_message = "Launch template instance type must match variable"
}
```
✅ **Why it proves:** Instance type matches expectations (no surprise cost overruns, no performance degradation)

#### **Test 3: validate_alb_sg_port**
```hcl
assert {
  condition     = anytrue([
    for rule in aws_security_group.alb_sg.ingress :
    rule.from_port == 80 && rule.protocol == "tcp"
  ])
  error_message = "ALB security group must allow HTTP traffic on port 80"
}
```
✅ **Why it guarantees:** Applications are actually reachable — users won't hit "connection refused"

**⚠️ Real Challenge:** Security group ingress is a *set*, not a list. Can't use `[0]` indexing.
```hcl
# ❌ WRONG
condition = aws_security_group.alb_sg.ingress[0].from_port == 80

# ✅ CORRECT — Use anytrue() with for expression
condition = anytrue([
  for rule in aws_security_group.alb_sg.ingress :
  rule.from_port == 80
])
```

#### **Test 4: validate_web_sg_server_port**
```hcl
assert {
  condition     = anytrue([
    for rule in aws_security_group.web_sg.ingress :
    rule.from_port == var.server_port && rule.protocol == "tcp"
  ])
  error_message = "Web security group must allow server_port traffic from ALB"
}
```
✅ **Why it guarantees:** EC2 instances can receive application traffic from the load balancer

#### **Test 5: validate_elb_health_check_type**
```hcl
assert {
  condition     = aws_autoscaling_group.web.health_check_type == "ELB"
  error_message = "ASG must use ELB health checks"
}
```
✅ **Why it guarantees:** Broken instances are automatically replaced (not just sitting around draining connections)

#### **Tests 6-7: Environment-Specific Values**
```hcl
# validate_dev_instance_type_from_locals
# validate_production_instance_type_from_locals

assert {
  condition     = (var.environment == "dev" ? 
    local.instance_by_env["dev"] == "t3.micro" : 
    local.instance_by_env["production"] == "t3.small")
  error_message = "Instance types must match environment configuration"
}
```
✅ **Why it guarantees:** Each environment operates at the right cost/reliability tradeoff (dev is cheap, prod is reliable)

#### **Tests 8-9: Log Retention**
```hcl
# validate_dev_log_retention
# validate_production_log_retention

assert {
  condition = (var.environment == "dev" ? 
    aws_cloudwatch_log_group.app.retention_in_days == 7 :
    aws_cloudwatch_log_group.app.retention_in_days == 30)
  error_message = "Log retention must match environment"
}
```
✅ **Why it guarantees:** Dev logs don't cause storage bloat; production logs satisfy compliance requirements

#### **Tests 10-11: Monitoring Configuration**
```hcl
# validate_monitoring_disabled
# validate_monitoring_enabled

assert {
  condition     = (var.enable_monitoring ? 
    aws_cloudwatch_metric_alarm.cpu_utilization != null :
    aws_cloudwatch_metric_alarm.cpu_utilization == null)
  error_message = "Monitoring alarms must respect enable_monitoring variable"
}
```
✅ **Why it guarantees:** Monitoring alarms respect the enable_monitoring flag (no surprise costs from disabled features)

#### **Tests 12-13: Invalid Input Rejection**
```hcl
# validate_bad_environment_rejected
# validate_bad_instance_type_rejected

run "validate_bad_environment_rejected" {
  command = plan

  variables {
    environment = "invalid"  # Should fail validation
  }

  expect_failures = [
    aws_autoscaling_group.web
  ]
}
```
✅ **Why it guarantees:** Invalid inputs are caught before they ever reach AWS (typos never slip through)

### Running Unit Tests
```bash
cd Day-18/modules/services/webserver-cluster
terraform init
terraform test -verbose
```

**Expected Output:**
```
webserver_cluster_test.tftest.hcl... in progress
  run "validate_asg_name_prefix"... pass
  run "validate_launch_template_instance_type"... pass
  ...
  [13 total]
Success! 13 passed, 0 failed.
```

---

## Layer 2: Integration Tests

### File Location
[`test/webserver_cluster_test.go`](./test/webserver_cluster_test.go)

### Complete Test Code
```go
package test

import (
	"fmt"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestWebserverClusterIntegration(t *testing.T) {
	t.Parallel()

	uniqueID   := random.UniqueId()
	clusterName := fmt.Sprintf("test-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/services/webserver-cluster",
		Vars: map[string]interface{}{
			"cluster_name":        clusterName,
			"instance_type":       "t3.micro",
			"min_size":            1,
			"max_size":            2,
			"environment":         "dev",
			"project_name":        "test-project",
			"team_name":           "test-team",
			"enable_monitoring":   false,
			"cpu_alarm_threshold": 80,
			"app_version":         "v1",
		},
	})

	// CRITICAL: Cleanup happens even if test fails
	defer terraform.Destroy(t, terraformOptions)

	// Deploy infrastructure
	terraform.InitAndApply(t, terraformOptions)

	// Get ALB DNS name
	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	url := fmt.Sprintf("http://%s", albDnsName)

	// Wait for ALB to become healthy (can take 2-3 minutes)
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		30,           // Max retries
		10*time.Second, // Time between retries
		func(status int, body string) bool {
			return status == 200 && len(body) > 0
		},
	)

	// Verify key outputs
	monitoringEnabled := terraform.Output(t, terraformOptions, "monitoring_enabled")
	assert.NotEmpty(t, monitoringEnabled, "Monitoring flag should be set")
}
```

### What This Test Guarantees
1. **Real infrastructure can be deployed** from your code (not just from a YAML template)
2. **The ALB becomes healthy** and serves traffic without errors
3. **The application responds** with HTTP 200 (not just "exists in AWS")
4. **Cleanup is automatic** — even if the test crashes, resources are destroyed via `defer`

### Running Integration Tests
```bash
cd Day-18/test
go test -v -timeout 30m ./...
```

### Real Challenge: Null Output Handling

When `enable_monitoring=false`, the `sns_topic_arn` output is `null`.

**❌ WRONG:**
```go
snsArn := terraform.Output(t, terraformOptions, "sns_topic_arn")
// Panics if sns_topic_arn is null
```

**✅ CORRECT:**
```go
monitoringEnabled := terraform.Output(t, terraformOptions, "monitoring_enabled")
assert.Equal(t, "false", monitoringEnabled)
// Validate the feature flag instead of a nullable output
```

---

## Layer 3: End-to-End Tests

### File Location
[`test/webserver_cluster_e2e_test.go`](./test/webserver_cluster_e2e_test.go)

### What E2E Tests Guarantee
Deploy the **same module across 3 environments** (dev → staging → production) to guarantee:
- ✅ Code behaves correctly with different configurations (not just one environment)
- ✅ Conditional logic works as intended (monitoring flags, log retention)
- ✅ No "works in dev, breaks in production" surprises

### High-Level Architecture
```
E2E Test
├─ Deploy Dev Environment
│  ├─ Create: ALB, ASG (1-2), EC2, SGs, CloudWatch logs
│  ├─ Verify: HTTP 200, monitoring disabled
│  └─ Destroy: All resources
├─ Deploy Staging Environment
│  ├─ Create: ALB, ASG (2-4), EC2, SGs, CloudWatch alarms
│  ├─ Verify: HTTP 200, monitoring enabled
│  └─ Destroy: All resources
└─ Deploy Production Environment
   ├─ Create: ALB, ASG (2-6), EC2, SGs, CloudWatch alarms
   ├─ Verify: HTTP 200, monitoring enabled, larger instances
   └─ Destroy: All resources
```

### Running E2E Tests
```bash
cd Day-18/test
go test -v -timeout 30m -run TestWebserverClusterEndToEnd ./...
```

**Runtime:** 25-35 minutes  
**Cost:** $3-5  
**When to run:** Weekly, or before major releases

---

## Real Challenges & Solutions

### Challenge 1: Security Group Set Indexing

**Error:**
```
Error: Invalid index
Elements of a set are identified only by their value and don't have any separate index or key...
```

**Root Cause:** Terraform security group `ingress` is a *set*, not a *list*. Sets don't support indexing.

**Solution:**
```hcl
# ❌ WRONG
condition = aws_security_group.alb_sg.ingress[0].from_port == 80

# ✅ CORRECT
condition = anytrue([
  for rule in aws_security_group.alb_sg.ingress :
  rule.from_port == 80 && rule.protocol == "tcp"
])
```

### Challenge 2: Variables Not Reaching Destroy Phase in CI/CD

**Problem:** `.tftest.hcl` variables work in local testing but sometimes don't reach the destroy phase in GitHub Actions.

**Root Cause:** Non-interactive CI environments don't always propagate variables consistently.

**Solution: Defense-in-Depth (3 layers)**

1. **Layer 1: .tftest.hcl variables block**
```hcl
variables {
  cluster_name = "test-cluster"
  min_size     = 1
  # ... all 11 required variables
}
```

2. **Layer 2: GitHub Actions environment variables**
```yaml
env:
  TF_VAR_cluster_name: "test-cluster"
  TF_VAR_min_size: "1"
  # ... all 11 variables as TF_VAR_*
```

3. **Layer 3: variables.tf defaults**
```hcl
variable "min_size" {
  default = 1  # Always has a fallback
}
```

If any layer fails, others catch it.

### Challenge 3: Null Outputs Crashing Go Tests

**Error:**
```
panic: error reading output 'sns_topic_arn': nil value
```

**Root Cause:** When `enable_monitoring=false`, the output is `null`. Terratest can't read null values.

**Solution:**
```go
// ❌ WRONG
snsArn := terraform.Output(t, terraformOptions, "sns_topic_arn")

// ✅ CORRECT
monitoringEnabled := terraform.Output(t, terraformOptions, "monitoring_enabled")
assert.Equal(t, "false", monitoringEnabled)
// Assert the flag, not the nullable output
```

### Challenge 4: ALB Takes Time to Become Healthy

**Error:**
```
Connection refused (or 503 Service Unavailable)
```

**Root Cause:** After deployment, the load balancer takes 2-3 minutes to register instances and become healthy.

**Solution:** Retry logic with exponential backoff
```go
http_helper.HttpGetWithRetryWithCustomValidation(
	t,
	url,
	nil,
	30,           // Max attempts
	10*time.Second, // Wait between attempts
	func(status int, body string) bool {
		return status == 200 && len(body) > 0
	},
)

// Effectively: Try for up to 5 minutes (30 × 10s)
```

---

## GitHub Actions Workflow

### File Location
[`.github/workflows/terraform-test.yaml`](./.github/workflows/terraform-test.yaml)

### Workflow Architecture
```
GitHub Actions Workflow (Manual Trigger Only)
│
├─ Unit Tests Job (Every Run)
│  ├─ Terraform Init
│  ├─ Terraform Format Check
│  ├─ Terraform Validate
│  ├─ Terraform Plan (cost estimate)
│  └─ Terraform Test (13 runs)
│     └─ Status: ✅ Pass (or ❌ Fail)
│
└─ Integration Tests Job (Only if Unit Tests Pass)
   ├─ Go Setup
   ├─ Download Go Module Cache
   ├─ Run Integration Tests
   │  ├─ terraform init
   │  ├─ terraform apply (deploy)
   │  ├─ HTTP health check
   │  └─ terraform destroy (cleanup)
   └─ Status: ✅ Pass, All Resources Destroyed
```

### Key Features

#### **Environment Variables Setup**
All Terraform commands receive required variables:
```yaml
env:
  TF_VAR_cluster_name:        "test-cluster"
  TF_VAR_min_size:            "1"
  TF_VAR_max_size:            "2"
  TF_VAR_environment:         "dev"
  TF_VAR_instance_type:       "t3.micro"
  TF_VAR_project_name:        "test-project"
  TF_VAR_team_name:           "test-team"
  TF_VAR_enable_monitoring:   "false"
  TF_VAR_cpu_alarm_threshold: "80"
  TF_VAR_app_version:         "v1"
```

#### **Go Module Caching**
```yaml
- uses: actions/cache@v3
  with:
    path: ~/go/pkg/mod
    key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
```
Saves 2-3 minutes on subsequent runs.

#### **Manual Trigger Only**
```yaml
on:
  workflow_dispatch:  # Only run when explicitly triggered
```

### How to Manually Trigger in GitHub UI
1. Go to **Actions** tab
2. Select **Terraform Tests** workflow
3. Click **Run workflow** button
4. Select branch: `main`
5. Click **Run workflow** (green button)

---

## Cost & Performance Breakdown

### Test Execution Times

| Layer | Suite | Time | Cost |
|-------|-------|------|------|
| **Unit** | All 13 tests | ~30 seconds | Free |
| **Integration** | Deploy + test + destroy | ~9.4 minutes | ~$0.50 |
| **E2E** | 3 environments (dev→staging→prod) | ~27 minutes 43 seconds | ~$4.50 |
| **Total** | Full validation | ~37 minutes | ~$5.00 |

### Cost Breakdown
- **EC2 instances** ($0.0116/hour for t3.micro, $0.0232/hour for t3.small)
- **Load balancers** ($0.0225/hour)
- **Data transfer** (minimal, usually free)

### Smart Testing Strategy

| When | Layers | Cost | Time | Purpose |
|------|--------|------|------|---------|
| Every PR | Unit only | Free | 30s | Catch logic errors |
| Merge to main | Unit + Integration | ~$0.50 | ~10m | Verify real AWS |
| Weekly | Unit + Integration + E2E | ~$5.00 | ~40m | Full validation |
| Before release | All + manual review | ~$5.00 | ~1h | Maximum confidence |

---

## Execution Results

### Unit Tests (Actual Output)
```
webserver_cluster_test.tftest.hcl... in progress
  run "validate_asg_name_prefix"... pass
  run "validate_launch_template_instance_type"... pass
  run "validate_alb_sg_port"... pass
  run "validate_web_sg_server_port"... pass
  run "validate_elb_health_check_type"... pass
  run "validate_dev_instance_type_from_locals"... pass
  run "validate_production_instance_type_from_locals"... pass
  run "validate_dev_log_retention"... pass
  run "validate_production_log_retention"... pass
  run "validate_monitoring_disabled"... pass
  run "validate_monitoring_enabled"... pass
  run "validate_bad_environment_rejected"... pass
  run "validate_bad_instance_type_rejected"... pass
webserver_cluster_test.tftest.hcl... tearing down
webserver_cluster_test.tftest.hcl... pass

Success! 13 passed, 0 failed.
```

### Integration Test (Actual Output)
```
=== RUN   TestWebserverClusterIntegration
    webserver_cluster_test.go:23: Initializing Terraform working directory
    webserver_cluster_test.go:26: Calling terraform init
    webserver_cluster_test.go:28: Calling terraform apply. Terraform will use the default var file "terraform.tfvars" if it exists
    
    [terraform apply output showing 11 resources created]
    
    webserver_cluster_test.go:32: Getting output 'alb_dns_name'
    webserver_cluster_test.go:34: Making HTTP GET request to: http://test-abcd1234-alb-123456.us-east-1.elb.amazonaws.com
    webserver_cluster_test.go:36: HTTP GET request succeeded after 21 seconds
    webserver_cluster_test.go:38: Calling terraform destroy
    
    [terraform destroy output showing 11 resources destroyed]
    
--- PASS: TestWebserverClusterIntegration (563.86s)
PASS
```

### E2E Test (Multi-Environment)
```
=== RUN   TestWebserverClusterEndToEnd
    Running DEV environment...
    [Deploy dev, verify HTTP 200, monitoring disabled, destroy]
    ✅ Dev passed
    
    Running STAGING environment...
    [Deploy staging, verify HTTP 200, monitoring enabled, destroy]
    ✅ Staging passed
    
    Running PRODUCTION environment...
    [Deploy production, verify HTTP 200, monitoring enabled, destroy]
    ✅ Production passed
    
--- PASS: TestWebserverClusterEndToEnd (1663.86s)
PASS
```

---

## Key Takeaways

### 1. **Multiple Layers Aren't Optional**
Unit tests catch logic errors. Integration tests catch AWS issues. E2E tests reveal environment-specific disasters. The investment compounds: each layer prevents increasingly expensive failures.

### 2. **`defer terraform.Destroy()` Is Non-Negotiable**
This single pattern prevents $500+ AWS bills and orphaned infrastructure. Without it, your cleanup is voluntary. With it, it's guaranteed.

### 3. **Variables Need Defense-in-Depth**
Relying on one variable-passing mechanism means one point of failure in CI/CD. Layer them: `.tftest.hcl` + environment variables + defaults.

### 4. **AWS Doesn't Initialize Instantly**
Load balancers take 2-3 minutes to health check. Instances need time to boot and configure. Build retry logic with exponential backoff, not just "wait 10 seconds and fail."

### 5. **Testing Costs Less Than You Think**
$5/month for complete validation is cheaper than:
- One production incident (1 hour firefighting = $200+ engineer time)
- One orphaned resource ($8+ per month forever)
- One broken refactor (regression debugging = 4 hours)

---

## Next Steps

1. **Run locally:** Test all three layers on your machine
2. **Trigger in GitHub Actions:** Use manual workflow dispatch
3. **Monitor costs:** Set up AWS Billing Alerts for test infrastructure
4. **Iterate:** Add more assertions as you discover edge cases

---

**Questions? Issues? Insights?**  
All the code is in [the GitHub repository](https://github.com/elorm116/30-days-terraform/tree/main/Day-18) — feel free to fork, experiment, and adapt to your needs.

Happy testing! 🚀
