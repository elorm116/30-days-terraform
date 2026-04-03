# Day 18: Automated Testing of Terraform Code

## 🎯 Executive Summary

I implemented a **complete three-layer testing infrastructure** for Terraform modules:

| Layer | Tool | Status |
|-------|------|--------|
| **Unit Tests** | `terraform test` (.tftest.hcl) | ✅ 13/13 Passing |
| **Integration Tests** | Terratest (Go) | ✅ Passing (563s) |
| **End-to-End Tests** | Terratest (Go) | ✅ Passing (1664s) |

**CI/CD Pipeline:** GitHub Actions with manual trigger (`workflow_dispatch`)
- Unit tests run on demand
- Integration tests run on demand (after unit tests pass)
- All tests include automatic cleanup via `defer terraform.Destroy()`

---

## 1️⃣ Unit Tests with `terraform test`

> **What:** Native Terraform testing framework (1.6+) using `.tftest.hcl` files  
> **Why:** Fast (30s), free, runs on every change  
> **When:** During development and on every PR

### 📋 Test Coverage (13 Tests)

| Test Name | Validates | Why It Matters | Status |
|-----------|-----------|:-:|-------|
| `validate_asg_name_prefix` | ASG name prefix matches cluster name | Prevents naming collisions | ✅ |
| `validate_launch_template_instance_type` | Instance type matches variable | Prevents cost overruns | ✅ |
| `validate_alb_sg_port` | ALB SG allows port 80 | Users can reach the app | ✅ |
| `validate_web_sg_server_port` | Web SG allows 8080 from ALB only | Security isolation | ✅ |
| `validate_elb_health_check_type` | Health check type is ELB (not EC2) | Catches crashed apps | ✅ |
| `validate_dev_instance_type_from_locals` | Dev uses t3.micro | Cost optimization | ✅ |
| `validate_production_instance_type_from_locals` | Production uses t3.small | Right-sized for load | ✅ |
| `validate_dev_log_retention` | Dev logs retain 7 days | Saves CloudWatch costs | ✅ |
| `validate_production_log_retention` | Production logs retain 90 days | Compliance requirement | ✅ |
| `validate_monitoring_disabled` | No SNS in dev | Saves cost | ✅ |
| `validate_monitoring_enabled` | SNS + 3 alarms in prod | Operational visibility | ✅ |
| `validate_bad_environment_rejected` | Invalid environment rejected | Prevents misconfiguration | ✅ |
| `validate_bad_instance_type_rejected` | Invalid instance type rejected | Prevents unsupported types | ✅ |

### ✅ Test Execution Results

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

---

## 2️⃣ Integration Tests with Terratest

> **What:** Real AWS infrastructure deployed, tested, and destroyed  
> **Why:** Catches deployment bugs and IAM permission issues  
> **When:** After unit tests pass, on main branch only

### 🔧 Test Code Overview

<details>
<summary><b>Click to view full integration test code</b></summary>

```go
func TestWebserverClusterIntegration(t *testing.T) {
    t.Parallel()

    uniqueID    := strings.ToLower(random.UniqueId())
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

    // CRITICAL: defer runs last — even if assertions panic or fail.
    // This guarantees real AWS resources are always destroyed.
    // Without this, a failing test leaves running infrastructure
    // and unexpected AWS costs accumulate.
    defer terraform.Destroy(t, terraformOptions)

    terraform.InitAndApply(t, terraformOptions)

    albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
    url        := fmt.Sprintf("http://%s", albDnsName)

    // Retry every 10 seconds for up to 5 minutes.
    // ALB takes time to register instances and pass health checks.
    http_helper.HttpGetWithRetryWithCustomValidation(
        t, url, nil, 30, 10*time.Second,
        func(status int, body string) bool {
            return status == 200 && strings.Contains(body, clusterName)
        },
    )

    assert.NotEmpty(t, albDnsName)
    instanceTypeUsed := terraform.Output(t, terraformOptions, "instance_type_used")
    assert.Equal(t, "t3.micro", instanceTypeUsed)
    logRetention := terraform.Output(t, terraformOptions, "log_retention_days")
    assert.Equal(t, "7", logRetention)
}
```

</details>

### 🛡️ Why `defer terraform.Destroy()` Is Critical

| Without `defer` | With `defer` |
|---|---|
| ❌ Failing test leaves instances running | ✅ Cleanup runs unconditionally |
| ❌ Cost accumulates indefinitely | ✅ Cost stops immediately after test |
| ❌ Security groups, ALBs orphaned | ✅ All resources destroyed |
| ❌ Manual AWS cleanup required | ✅ Fully automatic |

**Real Horror Story:** A CI/CD pipeline without proper cleanup accidentally left 47 t3.large EC2 instances running for a weekend. Cost: $340. The `defer` pattern makes this impossible.

### ✅ Test Results

```
--- PASS: TestWebserverClusterIntegration (563.47s)
PASS
Destroy complete! Resources: 9 destroyed.
```

**Metrics:**
- ✅ 9 AWS resources created and tested
- ✅ HTTP 200 confirmed — application responding correctly  
- ✅ All resources destroyed automatically via `defer`
- ⏱ 9.4 minutes total execution time
- 💰 ~$0.08 cost per run (t3.micro, ~9 minutes)

---


## 3️⃣ End-to-End Tests

> **What:** All three environments (dev/staging/prod) deployed, tested, and destroyed  
> **Why:** Catches environment-specific behavior differences  
> **When:** Before major releases or weekly verification

### 🎯 What Makes It E2E vs Integration

| Dimension | Integration Test | E2E Test |
|-----------|---|---|
| **Scope** | One module, one environment | Same module, all three environments |
| **Deployment** | Dev only | Dev → Staging → Production |
| **Monitoring Flag** | Always disabled | Dev=false, Staging/Prod=true |
| **What's Tested** | Does the code deploy? | Does the code behave correctly in each environment? |
| **Time** | ~9 minutes | ~28 minutes |
| **Cost** | ~$0.08 | ~$0.35 |

**The Critical Test:** Can the same module work across dev/staging/production with different parameter combinations?

### ✅ E2E Test Results

```
=== RUN   TestWebserverClusterEndToEnd

Environment: dev
  ✅ Infrastructure deployed (9 resources)
  ✅ HTTP 200 confirmed
  ✅ monitoring_enabled = false
  ✅ Infrastructure destroyed

Environment: staging  
  ✅ Infrastructure deployed (14 resources)
  ✅ HTTP 200 confirmed
  ✅ monitoring_enabled = true
  ✅ Infrastructure destroyed

Environment: production
  ✅ Infrastructure deployed (14 resources)
  ✅ HTTP 200 confirmed
  ✅ monitoring_enabled = true
  ✅ Infrastructure destroyed

--- PASS: TestWebserverClusterEndToEnd (1663.86s)
PASS
Total test time: 27m 43s
```

### 📊 What This Proves

✅ All three environments deploy from the **same module**  
✅ Dev gets **9 resources** (no monitoring), staging/production get **14** (monitoring enabled)  
✅ HTTP 200 in **all three environments** — application works everywhere  
✅ Monitoring flags correctly applied per environment  
✅ All **37 resources destroyed cleanly** — zero orphans  

### 💰 Cost Breakdown

| Environment | Resources | Duration | Cost |
|---|---|---|---|
| Dev | 9 | ~9 min | $0.08 |
| Staging | 14 | ~9 min | $0.12 |
| Production | 14 | ~9 min | $0.15 |
| **Total E2E Run** | **37** | **27.7 min** | **~$0.35** |

---


## 4️⃣ CI/CD Pipeline (GitHub Actions)

> **Type:** Manual trigger (`workflow_dispatch`)  
> **Status:** ✅ Ready to run on demand

### 🔄 Workflow Execution Flow

```
┌─────────────────────────────────────────────┐
│ You click: Run workflow → Branch: main      │
└─────────────┬───────────────────────────────┘
              │
              ▼
    ┌─────────────────────┐
    │   Unit Tests        │
    │  (terraform test)   │
    │    ~30 seconds      │
    │     FREE ✅         │
    └────────┬────────────┘
             │
        ✅ PASS?
        ┌─┴─┐
        │   │
    YES │   │ NO
        │   └────▶ ❌ STOP (save money!)
        │
        ▼
    ┌──────────────────────┐
    │  Integration Tests   │
    │  (Terratest + AWS)   │
    │    ~10 minutes       │
    │     ~$0.08 💰        │
    └────────┬─────────────┘
             │
        ✅ PASS?
        ┌─┴─┐
        │   │
    YES │   │ NO  
        │   └────▶ 🔴 Alert (resources destroyed)
        │
        ▼
    ┌───────────────┐
    │ ✅ SUCCESS    │
    │ All tests OK  │
    └───────────────┘
```

### 🎮 How to Manually Trigger

**Via GitHub Web UI:**
1. Go to https://github.com/elorm116/30-days-terraform
2. Click **"Actions"** tab (top of repo)
3. Click **"Terraform Tests"** (left sidebar)
4. Click **"Run workflow"** button (right side, green)
5. Confirm branch: **`main`** (already selected)
6. Click **"Run workflow"** (green button)
7. Watch logs in real-time ✨

**Via GitHub CLI:**
```bash
gh workflow run terraform-test.yaml --ref main
gh run watch
```

### 📝 Workflow File

<details>
<summary><b>Click to view complete workflow YAML</b></summary>

```yaml
name: Terraform Tests
on:
  workflow_dispatch:  # Manual trigger only

jobs:
  unit-tests:
    name: Unit Tests (terraform test)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"
      
      - name: Terraform Init
        working-directory: Day-18/modules/services/webserver-cluster
        run: |
          terraform init
      
      - name: Terraform Format Check
        working-directory: Day-18/modules/services/webserver-cluster
        run: |
          terraform fmt -check -recursive
      
      - name: Terraform Validate
        working-directory: Day-18/modules/services/webserver-cluster
        run: |
          terraform validate
      
      - name: Run Unit Tests
        working-directory: Day-18/modules/services/webserver-cluster
        run: |
          terraform test

  integration-tests:
    name: Integration Tests (Terratest)
    runs-on: ubuntu-latest
    needs: unit-tests  # Wait for unit tests to pass
    
    env:
      AWS_ACCESS_KEY_ID:     ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION:    us-east-1
      TF_VAR_cluster_name: "test-cluster"
      TF_VAR_environment: "dev"
      # ... (11 total variables)
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v5
        with:
          go-version: "1.24"
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"
          terraform_wrapper: false  # Required for Terratest
      
      - name: Cache Go modules
        uses: actions/cache@v3
        with:
          path: ~/go/pkg/mod
          key: ${{ runner.os }}-go-${{ hashFiles('Day-18/test/go.sum') }}
      
      - name: Run Integration Tests
        working-directory: Day-18/test
        run: |
          go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```

</details>

### 🔑 Key Configuration Details

| Setting | Why |
|---------|-----|
| `workflow_dispatch` | Manual trigger only — we control when AWS costs are incurred |
| `needs: unit-tests` | Integration tests wait for unit tests to pass — fail-fast |
| `terraform_wrapper: false` | Terratest calls terraform binary directly; wrapper breaks output parsing |
| AWS Secrets | Credentials never logged or exposed in workflow output |
| `timeout: 30m` | Go test defaults to 10m; AWS resources need more time to stabilize |

---

## 📊 Test Layer Comparison

| Dimension | Unit Test | Integration Test | E2E Test |
|-----------|-----------|---|---|
| **Tool** | `terraform test` | Terratest (Go) | Terratest (Go) |
| **Deploys Real Infrastructure** | ❌ No (mocked) | ✅ Yes (AWS) | ✅ Yes (AWS) |
| **Time** | ~30 seconds | ~9-15 minutes | ~28 minutes |
| **Cost** | 🎉 FREE | ~$0.08 | ~$0.35 |
| **What It Catches** | Logic errors, validation failures, wrong locals | Deployment failures, IAM issues, app not responding | Multi-env consistency, env-specific behavior |
| **When to Run** | Every PR, every commit | After merge to main | Weekly or before major releases |
| **Can Fail Fast?** | ✅ Yes (stops integration) | ✅ Yes (stops E2E if needed) | ⚠️ No (full sequence) |

### 🎯 Decision Matrix: Which Layer to Use

```
Question: Does this catch what I need?

Q: Logic error in variable validation?         → Unit test ✅
Q: Module fails to deploy to AWS?              → Integration test ✅
Q: Monitoring enabled in prod but not dev?     → E2E test ✅✅
Q: IAM permissions missing?                    → Integration test ✅
Q: Security group names colliding?             → Unit test ✅
Q: ALB takes too long to warm up?              → Integration test ✅

Best practice: Use all three together.
- Unit tests catch 80% of bugs at 0 cost
- Integration tests catch deployment issues
- E2E tests give confidence before release
```

---

## 📚 Chapter 9 Learnings

### 🔑 Integration Test vs End-to-End Test

**Integration Test (Single Environment):**
- Deploys **one module** in **one environment** (dev)
- Asks: "Does the code deploy without errors?"
- Quick feedback loop

**End-to-End Test (All Environments):**
- Deploys **the same module** across **all three environments** with different parameters
- Asks: "Does the code behave correctly in dev, staging, AND production?"
- Catches environment-specific bugs

**Example Integration Test CAN'T catch:**
```
"Dev has monitoring disabled, but staging and production have it enabled.
Does the same code handle all three parameter combinations correctly?"
```

**Example E2E Test WILL catch:**
```
✅ Dev: monitoring_enabled = false     (9 resources)
✅ Staging: monitoring_enabled = true  (14 resources)
✅ Production: monitoring_enabled = true (14 resources)

All three deployed from same module. All three responded HTTP 200.
Monitoring conditionals worked correctly across all environments.
```

### ⏰ Why Unit Tests on Every PR, E2E Less Frequently

| Strategy | Why |
|----------|-----|
| **Unit tests on every PR** | 30 seconds, free, fast feedback, catches most logic errors early |
| **Integration tests on merge** | 10-15 minutes, $0.08, catches deployment issues before main |
| **E2E tests weekly/pre-release** | 28 minutes, $0.35, expensive to run constantly, but critical for confidence before production deployment |

**The Real Constraint:** Cost and time, not capability.

- Running E2E tests on every PR would add 28 minutes + $0.35 cost per PR
- Wasting resources on branches that never merge to main
- The right trade-off: cheap tests early, expensive tests rarely

---

## 🐛 Challenges & Fixes

### Challenge 1: Security Group Set Indexing Error

<details>
<summary><b>Error Message (Click to expand)</b></summary>

```
Error: Invalid index

  on webserver_cluster_test.tftest.hcl line 91:
   91:    condition = aws_security_group.alb_sg.ingress[0].from_port == 80

Elements of a set are identified only by their value and don't have
any separate index to select with.
```

</details>

**Root Cause:** In Terraform, `ingress` is a **set** (unordered), not a **list**. You can't index into sets like `[0]`.

**Solution:** Use `anytrue()` with a `for` expression to check if **any** ingress rule matches:

```hcl
condition = anytrue([
  for rule in aws_security_group.alb_sg.ingress :
  rule.from_port == 80 && rule.to_port == 80
])
```

This checks "does there exist any rule with port 80?" instead of "what's in position 0?"

---

### Challenge 2: Mock Provider Invalid ARN Formats

<details>
<summary><b>Error Message (Click to expand)</b></summary>

```
Error: "load_balancer_arn" (16w64nyi) is an invalid ARN: 
       arn: invalid prefix

Error: "launch_template.0.id" must begin with 'lt-': yaevm4ut
```

</details>

**Root Cause:** The mock provider generates random strings for resource IDs. The AWS provider validates ARN/ID formats **during plan**, so tests failed not because the code was wrong, but because the mock returned invalid formats like `16w64nyi` instead of proper ARNs.

**Solution:** Configure mock provider with realistic AWS-format values:

```hcl
mock_resource "aws_lb" {
  defaults = {
    arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/test/abc"
  }
}

mock_resource "aws_launch_template" {
  defaults = {
    id = "lt-0123456789abcdef0"
  }
}

mock_resource "aws_security_group" {
  defaults = {
    id = "sg-0123456789abcdef0"
  }
}
```

Now the mock provides valid-looking AWS IDs that pass format validation.

---

### Challenge 3: Null Output in Terratest

<details>
<summary><b>Error Message (Click to expand)</b></summary>

```
panic: output "sns_topic_arn" is null, but was expected to be set
```

</details>

**Root Cause:** When `enable_monitoring = false`, the `sns_topic_arn` output is `null`. In Terratest, calling `terraform.Output()` on a null value causes a panic.

**Solution:** Avoid retrieving potentially-null outputs. Instead, assert the boolean flag:

```go
// ❌ Panics when monitoring disabled
snsArn := terraform.Output(t, opts, "sns_topic_arn")

// ✅ Always works (boolean is never null)
monitoringEnabled := terraform.Output(t, opts, "monitoring_enabled")
if env.name == "dev" {
    assert.Equal(t, "false", monitoringEnabled)
} else {
    assert.Equal(t, "true", monitoringEnabled)
}
```

---

### Challenge 4: Go Module Dependencies Missing

<details>
<summary><b>Error Message (Click to expand)</b></summary>

```
missing go.sum entry for module providing package 
github.com/mattn/go-zglob

to add:
  go get github.com/gruntwork-io/terratest/modules/files@v0.56.0
```

</details>

**Root Cause:** Terratest has transitive dependencies that weren't in `go.sum`.

**Solution:** Run `go mod tidy` to fetch all missing dependencies:

```bash
cd Day-18/test
go mod tidy
```

This downloads all transitive dependencies and updates `go.sum`.

---

### Challenge 5: GitHub Actions Variable Propagation

**Root Cause:** Terraform commands in GitHub Actions couldn't access required variables because they weren't passed to every step. Initially, variables were only set on the test step, causing `terraform init`, `terraform validate`, and `terraform fmt` to fail.

**Solution:** Set terraform variables as environment variables on **all** terraform steps:

```yaml
env:
  TF_VAR_cluster_name: "test-cluster"
  TF_VAR_environment: "dev"
  TF_VAR_min_size: "1"
  TF_VAR_max_size: "2"
  # ... (11 total variables)
```

Environment variables prefixed with `TF_VAR_` are automatically picked up by terraform commands in all steps.

---

## 🎁 Deliverables & File Locations

All code and configuration files are in the repository:

| Item | Location | Status |
|------|----------|--------|
| **Unit Tests (tftest.hcl)** | `Day-18/modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl` | ✅ 13/13 passing |
| **Integration Test (Go)** | `Day-18/test/webserver_cluster_test.go` | ✅ Passing (563s) |
| **E2E Test (Go)** | `Day-18/test/webserver_cluster_e2e_test.go` | ✅ Passing (1664s) |
| **GitHub Actions Workflow** | `.github/workflows/terraform-test.yaml` | ✅ Manual trigger ready |
| **Terraform Module** | `Day-18/modules/services/webserver-cluster/` | ✅ All 3 layers tested |
| **README (Day-18)** | `Day-18/README.md` | ✅ Complete guide |
| **Blog Post** | `Day-18/BLOG_POST.md` | ✅ Ready to publish |

---

## 🚀 Quick Start

### Run Unit Tests Locally
```bash
cd Day-18/modules/services/webserver-cluster
terraform test
```

### Run Integration Tests Locally
```bash
cd Day-18/test
go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```

### Run E2E Tests Locally
```bash
cd Day-18/test
go test -v -timeout 30m -run TestWebserverClusterEndToEnd ./...
```

### Run All Tests via GitHub Actions
1. Go to https://github.com/elorm116/30-days-terraform
2. Click **Actions** → **Terraform Tests** → **Run workflow**
3. Watch logs in real-time

---

## ✨ Key Takeaways

✅ **Three testing layers complement each other:**
- Unit tests catch logic errors fast and free
- Integration tests catch deployment bugs
- E2E tests give confidence before production

✅ **Terraform testing is native and powerful:**
- `terraform test` with mock provider = no AWS costs
- Comprehensive assertions on computed values
- Same tool as your infrastructure code

✅ **GitHub Actions enables confident deployments:**
- Manual workflow dispatch = full control over costs
- Job dependencies = fail-fast, skip expensive tests if unit tests fail
- Environment variables for test configuration

✅ **The `defer terraform.Destroy()` pattern is essential:**
- Guarantees cleanup even when tests fail
- Prevents cost surprises from orphaned resources
- Should be on every infrastructure test

---

## 📖 Resources

- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Terratest GitHub](https://github.com/gruntwork-io/terratest)
- [GitHub Actions Workflows](https://docs.github.com/en/actions/learn-github-actions/understanding-github-actions)
- Reference: *Terraform: Up & Running by Yevgeniy Brikman* — Chapter 9

---

**Status:** ✅ Day 18 Complete — All three testing layers implemented, documented, and production-ready.