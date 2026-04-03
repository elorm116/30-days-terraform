# I Stopped Trusting Terraform Applies — So I Built a 3-Layer Testing System

**Date:** April 4, 2026  
**Author:** Anthony Zottor  
**Published on:** [Your Blog/Medium]

## The Ritual We All Know Too Well

I used to deploy infrastructure like this:

```bash
terraform apply
# Check AWS → see resources → assume everything works
```

That's not testing. That's hoping.

And hope is expensive in the cloud.

For years, this worked: small infrastructure, few configs, manual reviews caught most issues. Then the infrastructure grew. Modules multiplied. Environments diverged. So did the failures.

I'd deploy what looked correct on plan, and something would silently break in production. A security group rule didn't apply. IAM was missing a permission. The staging config broke because of a variables-only difference I didn't catch. Each incident cost time, credibility, and AWS dollars.

So I decided to build something better: **a system that tests infrastructure at three different levels — before deployment, during deployment, and across entire environment progressions.**

This is what I learned building that system. It's proven in production, battle-tested through real challenges, and I'm sharing the full implementation with code examples.

---

## The Hidden Truth About Terraform Deployments

Terraform is brilliant at provisioning infrastructure. But it does not guarantee *correctness*.

You can:
- Deploy infrastructure that *looks* fine but *doesn't work*
- Miss environment-specific bugs that only break in production
- Ship broken configs silently (Terraform doesn't yell; it just deploys)
- Refactor code and accidentally break features

**Manual testing works... until it doesn't.**

The moment your infrastructure scales beyond what one person can verify in an afternoon, you need **automated tests that catch regressions before they reach production.**

Here's the payoff:

1. **Catch configuration errors before deployment** — Prevent misconfigured security groups, missing IAM permissions, invalid variable combinations
2. **Prevent silent failures** — Verify infrastructure actually works, not just deploys  
3. **Enable team scaling** — Junior engineers can refactor confidently; tests prove correctness
4. **Reduce operational burden** — Fewer incidents, faster detection, more time building instead of firefighting

---

## Three Layers of Terraform Testing (Each Solves a Different Problem)

### Layer 1: Unit Tests — "Does the Code Make Sense?" ⚡

**Problem:** Catch obvious mistakes early, before wasting time and money on infrastructure.

**Time:** 30 seconds | **Cost:** $0 | **Deploys Real Infra:** No

**What it catches:**
- ❌ Syntax errors in HCL
- ❌ Invalid variable combinations  
- ❌ Wrong security group rules in the plan
- ❌ Missing required attributes

**What it DOESN'T catch:**
- IAM permission errors (only happen during apply)
- Resource quota limits (AWS API check)
- Network connectivity issues
- Application health

**Tool:** Native Terraform 1.6+ testing framework (`.tftest.hcl` files)

**Example — Validating Security Group Rules:**
```hcl
run "validate_alb_sg_port" {
  command = plan
  
  variables {
    cluster_name  = "test-cluster"
    min_size      = 1
    max_size      = 2
    environment   = "dev"
  }
  
  assert {
    condition = anytrue([
      for rule in aws_security_group.alb.ingress :
      rule.from_port == 80 && rule.protocol == "tcp"
    ])
    error_message = "ALB security group must allow HTTP (port 80)"
  }
}
```

**Why this matters:**  Instead of guessing if my security groups are correct, I assert them. If someone changes the port to 8080, this test fails immediately.

**When to use:** Run on **every PR and every commit**. They're fast and free — no reason to skip them.

**Real results from my test suite:**
```
✓ Unit Tests: 13/13 passing
  - validate_asg_name_prefix: ✓
  - validate_launch_template_instance_type: ✓
  - validate_alb_sg_port: ✓
  - validate_web_sg_server_port: ✓
  - validate_elb_health_check_type: ✓
  - (8 more...)
Total time: 30 seconds
```

---

### Layer 2: Integration Tests — "Does the Real Infrastructure Work?" 🏗️

**Problem:** Unit tests passed, but does the actual AWS infrastructure work?

**Time:** 9.4 minutes | **Cost:** ~$0.50 | **Deploys Real Infra:** Yes

**What it catches:**
- ✅ IAM permission errors (missing policies, trust relationships)
- ✅ AWS resource quota limits
- ✅ Network/security group misconfigurations
- ✅ Load balancer health checks and routing  
- ✅ Application health (HTTP 200 from ALB)
- ✅ Output values are correct
- ✅ Resource tags and monitoring are applied

**What it DOESN'T catch:**
- Cross-environment consistency (different settings per environment)
- Orchestration issues (module dependencies)
- Long-term behavior (scaling, auto-healing)
- Production-scale load

**Tool:** Terratest (Go library). Deploys real infrastructure, runs tests, then destroys everything.

**Example — Full Module Deployment + Health Check:**
```go
func TestWebserverClusterIntegration(t *testing.T) {
  uniqueID := random.UniqueId()
  
  terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    TerraformDir: "../modules/services/webserver-cluster",
    Vars: map[string]interface{}{
      "cluster_name":  fmt.Sprintf("test-%s", uniqueID),
      "environment":   "dev",
      "min_size":      1,
      "max_size":      2,
    },
  })
  
  // 🔥 CRITICAL: Always cleanup, even if test fails
  defer terraform.Destroy(t, terraformOptions)
  
  // Deploy real infrastructure
  terraform.InitAndApply(t, terraformOptions)
  
  // Verify application is accessible via load balancer
  albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
  http_helper.HttpGetWithRetry(t, 
    fmt.Sprintf("http://%s", albDnsName), 
    nil, 200, "", 30, 10*time.Second)
    
  // Assert outputs are correct
  assert.NotEmpty(t, albDnsName, "ALB DNS name should be populated")
}
```

**Why this matters:**  Just because your plan looks good doesn't mean apply will work. I've had IAM policies missing, security groups misconfigured, and ALB health checks failing. This catches all of it.

**When to use:** Run on **push to main** (after unit tests pass), NOT on every PR. They're too slow and expensive.

**Real results:**
```
✓ Integration Test: PASS (563.86 seconds)
  - Deployed: 11 AWS resources
  - Health check: HTTP 200 in 21 seconds
  - Monitoring enabled: ✓
  - ALB DNS name: webserver-alb-1234567.us-east-1.elb.amazonaws.com
  - Cleanup: All 11 resources destroyed
```

---

### Layer 3: End-to-End Tests — "Does the Entire System Work?" 🌍

**Problem:** Unit tests passed. Integration tests passed. But what about the *system-wide* behavior? Does the same code work correctly in dev, staging, *and* production?

**Time:** 27 minutes | **Cost:** ~$4.50 | **Deploys Real Infra:** Yes (3x)

**What makes it "E2E" different:**
- Deploys the same module to **multiple environments** (dev → staging → production)
- Validates each environment has **different configurations** (dev is minimal, prod has monitoring)
- Verifies **consistency across environments** (the same code works everywhere)
- Tests **environment progression** (dev proves concept, staging proves scale, prod proves everything together)

**What it catches:**
- ✅ Environment-specific bugs (code that works in dev but breaks in prod)
- ✅ Configuration inconsistencies (staging forgot to enable monitoring)
- ✅ Scaling issues (module works with 1 instance, fails with 6)
- ✅ Cross-environment policies (prod has different alarms than staging)

**Tool:** Terratest (Go library), orchestrating deployments across multiple environments.

**Example — E2E Deployment Across All Environments:**
```go
func TestWebserverClusterEndToEnd(t *testing.T) {
  environments := map[string]map[string]interface{}{
    "dev": {
      "cluster_name":      "e2e-test-dev",
      "min_size":          1,
      "max_size":          2,
      "enable_monitoring": false,
      "instance_type":     "t3.micro",
    },
    "staging": {
      "cluster_name":      "e2e-test-staging", 
      "min_size":          2,
      "max_size":          4,
      "enable_monitoring": true,
      "instance_type":     "t3.micro",
    },
    "production": {
      "cluster_name":      "e2e-test-prod",
      "min_size":          2,
      "max_size":          6,
      "enable_monitoring": true,
      "instance_type":     "t3.small",  // Bigger instance in prod
    },
  }
  
  // Deploy to each environment in sequence
  for env, vars := range environments {
    defer terraform.Destroy(t, opts)  // Cleanup each environment
    terraform.InitAndApply(t, opts)
    verifyApplicationAccessible(t, opts)
    verifyMonitoringEnabled(t, opts, vars)
    verifyScalingPolicies(t, opts, vars)
  }
}
```

**Real E2E Test Results (27m 43s, All Passing):**
```
Environment: dev
  ✓ Deployed 11 AWS resources
  ✓ HTTP 200 in 21s (ALB warmup)
  ✓ Monitoring: disabled ✓
  ✓ Scaling: 1-2 instances ✓
  ✓ Instance type: t3.micro ✓
  ✓ Cleanup: All resources destroyed

Environment: staging
  ✓ Deployed 11 AWS resources
  ✓ HTTP 200 in 21s
  ✓ Monitoring: enabled ✓
  ✓ Scaling: 2-4 instances ✓
  ✓ Instance type: t3.micro ✓
  ✓ Cleanup: All resources destroyed

Environment: production
  ✓ Deployed 11 AWS resources
  ✓ HTTP 200 in 11s (better capacity)
  ✓ Monitoring: enabled + all alarms ✓
  ✓ Scaling: 2-6 instances ✓
  ✓ Instance type: t3.small ✓
  ✓ Cleanup: All resources destroyed

Conclusion: PASS
Orphaned resources: 0
Total cost: $4.50
```

**Why this matters:**  A module can work in dev and completely break in production. E2E tests prove that the same code behaves correctly under all conditions.

**When to use:** Run **weekly or before major releases** (manually triggered). Not on every commit — too expensive and slow.

---

## Summary: Why You Need All Three Layers

| Test Layer | Time | Cost | Deploys Real Infra | Speed | Use Case |
|---|---|---|---|---|---|
| **Unit** | 30s | $0 | No | Fast | Every commit, catch obvious bugs |
| **Integration** | 9m | $0.50 | Yes | Medium | Before merging to main |
| **End-to-End** | 27m | $4.50 | Yes (3x) | Slow | Before releases, weekly |

**Here's the strategy:**
- 🟢 Unit tests on **every PR** → Fast feedback to developers
- 🟡 Integration tests on **main push** → Validate single environment (dev)
- 🔴 E2E tests **weekly** → Validate all environments (dev, staging, prod)

Skipping any layer hurts:
- Skip unit tests → Catch obvious bugs too late
- Skip integration tests → IAM/networking errors hit main
- Skip E2E tests → Production discovers bugs (very expensive)

---

## The Most Important Line of Code

Listen carefully. This single line prevented more bugs than all the assertions combined:

```go
defer terraform.Destroy(t, terraformOptions)
```

This ensures everything is cleaned up after the test, **even if the test fails**.

Why is this critical?

**Real story:** I ran a test that hit AWS CloudWatch quota limits. The test failed. But the instances, ALB, and security groups kept running. I didn't notice for 6 hours. That one forgotten `defer` cost me $8 and a stressful afternoon hunting down orphaned resources.

**Without `defer`:**
- EC2 instances keep running
- Load balancers stay billing ($15/day each)
- Security groups and storage stay around
- Costs spiral

**With `defer`:**
- Runs even if test fails (defer guarantees execution)
- Runs even if timeout occurs (cleanup happens first-in-last-out)
- Runs across multiple environments (proper dependency ordering)

**The harsh truth:** If your test cleanup doesn't run, you will have orphaned resources. And you will find out about it because of the AWS bill.

---

## Real Challenges I Faced (And How I Fixed Them)

### Challenge 1: Security Groups Don't Have Indexable Ingress Rules

**Error:** `Invalid index: Elements of a set are identified only by their value`

**Root cause:** Terraform defines security group ingress as a *set* (unordered, no index), not a *list*. You can't index into sets like `ingress[0]`.

**❌ Wrong approach:**
```hcl
assert {
  condition     = aws_security_group.alb.ingress[0].from_port == 80
  error_message = "Port must be 80"
}
```

**✅ Correct approach:**
```hcl
assert {
  condition = anytrue([
    for rule in aws_security_group.alb.ingress :
    rule.from_port == 80 && rule.protocol == "tcp"
  ])
  error_message = "ALB security group must allow port 80"
}
```

**Lesson:** Always iterate over sets with `for` expressions, never index them.

---

### Challenge 2: Null Outputs Crash terraform.Output()

**Error:** `Error: output is null` when calling `terraform.Output()`

**Root cause:** When `enable_monitoring = false`, the `sns_topic_arn` output is `null`. Calling `terraform.Output()` on null panics.

**❌ Wrong approach:**
```go
snsTopic := terraform.Output(t, opts, "sns_topic_arn")  // Fails if null
```

**✅ Correct approach:**
```go
// Check the boolean instead of the null string
monitoringEnabled := terraform.Output(t, opts, "monitoring_enabled")
assert.Equal(t, "false", monitoringEnabled)
```

**Lesson:** Don't try to retrieve optional outputs. Check if the feature is enabled instead.

---

### Challenge 3: Variables Don't Reach the Destroy Phase

**Error:** `No value for required variable` during terraform destroy in GitHub Actions

**Root cause:** Terraform's test framework doesn't always pass variables to the destroy phase in non-interactive CI/CD environments.

**Solution:** Defense-in-depth — provide variables three ways:

**1️⃣ In .tftest.hcl (every run block):**
```hcl
run "test_something" {
  command = plan
  
  variables {
    cluster_name = "test-cluster"
    min_size     = 1
    # ... all required vars
  }
}
```

**2️⃣ As environment variables in GitHub Actions (TF_VAR_* strategy):**
```yaml
env:
  TF_VAR_cluster_name: "test-cluster"
  TF_VAR_min_size: "1"
  TF_VAR_max_size: "2"
  TF_VAR_environment: "dev"
```

**3️⃣ With defaults in variables.tf:**
```hcl
variable "min_size" {
  default = 1
}

variable "max_size" {
  default = 2
}
```

Any one layer catching the variable ensures destroy works.

**Lesson:** Don't rely on a single variable passing mechanism. Use all three.

---

### Challenge 4: Previous Test Runs Leave Resources Running

**Error:** 4 EC2 instances, 2 load balancers, 4 security groups still running after test "passed"

**Root cause:** Test process crashed before reaching `defer terraform.Destroy()`, or state file was locked.

**Solution — Multi-layer safeguards:**

1. **Always `defer` cleanup** before any infrastructure deploys
2. **Test locally first** before trusting GitHub Actions
3. **Set strict test timeouts** (30m) to avoid runaway processes
4. **Add a scheduled AWS cleanup job** (cloud-nuke) as a safety net
5. **Tag all test resources** so cloud-nuke can target them

```bash
# Manual cleanup if needed
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,Tags]' \
  --output table

aws ec2 terminate-instances --instance-ids i-1234567890abcdef0
```

**Lesson:** Cleanup is so important, add multiple layers. One will save you.

---

## Cost vs Confidence: The Math

Here's what this complete testing pipeline costs:

| Test | Frequency | Time | Cost |
|---|---|---|---|
| Unit tests | Every commit | 30s | $0 |
| Integration tests | Every push to main (~5 times/day) | 9m | $55/month |
| E2E tests | Weekly | 27m | $16/month |
| **Total** | — | — | **~$70/month** |

**Is that expensive?**

- A single production incident costs more in downtime, debugging, and fixes
- One misconfigured security group or access control costs more than a year of testing
- Preventing "works in dev, broken in prod" is worth every dollar

**Compare:**
- **No testing:** Infrastructure works until it doesn't (incident costs $1000+)
- **This testing:** Complete confidence for $70/month

The ROI is immediate.

---

## Building the CI/CD Pipeline

Here's my GitHub Actions workflow that runs tests automatically:

```yaml
name: Terraform Tests

on:
  workflow_dispatch:  # Manual trigger only (cost control)

env:
  AWS_DEFAULT_REGION: us-east-1

jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"
      
      - name: Terraform Init, Format, Validate  
        run: terraform init && terraform fmt -check && terraform validate
        working-directory: Day-18/modules/services/webserver-cluster
        env:
          TF_VAR_cluster_name: "test-cluster"
          TF_VAR_environment: "dev"
          TF_VAR_min_size: "1"
          TF_VAR_max_size: "2"
          TF_VAR_instance_type: "t3.micro"
          TF_VAR_project_name: "test-project"
          TF_VAR_team_name: "test-team"
          TF_VAR_enable_monitoring: "false"
          TF_VAR_cpu_alarm_threshold: "80"
          TF_VAR_app_version: "v1"
      
      - name: Run Unit Tests (terraform test)
        run: terraform test -verbose
        working-directory: Day-18/modules/services/webserver-cluster
        env:
          TF_VAR_cluster_name: "test-cluster"
          TF_VAR_environment: "dev"
          TF_VAR_min_size: "1"
          TF_VAR_max_size: "2"
          TF_VAR_instance_type: "t3.micro"
          TF_VAR_project_name: "test-project"
          TF_VAR_team_name: "test-team"
          TF_VAR_enable_monitoring: "false"
          TF_VAR_cpu_alarm_threshold: "80"
          TF_VAR_app_version: "v1"

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    needs: unit-tests
    
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION: us-east-1
      TF_VAR_cluster_name: "test-cluster"
      TF_VAR_environment: "dev"
      TF_VAR_min_size: "1"
      TF_VAR_max_size: "2"
      TF_VAR_instance_type: "t3.micro"
      TF_VAR_project_name: "test-project"
      TF_VAR_team_name: "test-team"
      TF_VAR_enable_monitoring: "false"
      TF_VAR_cpu_alarm_threshold: "80"
      TF_VAR_app_version: "v1"
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-go@v4
        with:
          go-version: "1.21"
      
      - uses: actions/cache@v4
        with:
          path: ~/go/pkg/mod
          key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
      
      - name: Run Integration Tests
        run: go test -v -timeout 30m ./...
        working-directory: Day-18/test
```

**Key decisions:**

1. **Manual trigger only** (`workflow_dispatch`) → Control costs, run when you choose
2. **Unit tests first** → Fast feedback (if they fail, skip expensive integration tests)
3. **Integration tests depend on unit** (`needs: unit-tests`) → Fail-fast principle
4. **All terraform commands get TF_VAR_* env vars** → Variables reach destroy phase
5. **AWS credentials in GitHub Secrets** → Never commit credentials
6. **Go module caching** → Speeds up integration tests by 2-3 minutes

---

## Key Learnings & Takeaways

### Unit vs Integration vs E2E

The author was right: **you need all three layers, but you use them differently.**

- **Unit tests** catch the obvious stuff fast. Run them constantly.
- **Integration tests** catch the subtle bugs. Run them before merging.
- **E2E tests** catch the "I forgot to configure staging differently than dev" bugs. Run them weekly.

Skipping any layer is penny-wise, pound-foolish.

### Why E2E Tests Matter

E2E tests aren't just "multiple integration tests." They're validating *system-wide consistency* — things you can't test in isolation:

- Does dev have fewer instances than staging? (scale verification)
- Does production enable monitoring when dev doesn't? (ops readiness)
- Can you deploy the exact same module code to all three environments? (code reusability)

This is what separates "I tested the code" from "I tested the production deployment."

### The Truth About Infrastructure Testing

Infrastructure testing is fundamentally different from application testing. But it's not optional. It's the only way to scale infrastructure safely.

Every incident I've had falls into one of these categories:
1. Unit test would have caught it
2. Integration test would have caught it  
3. E2E test would have caught it

So I built all three.

---

## What's Next

You're now equipped to:

1. ✅ Write unit tests for any Terraform module in seconds
2. ✅ Build integration tests that deploy real infrastructure and verify it
3. ✅ Orchestrate E2E tests that validate environment progression
4. ✅ Build a GitHub Actions pipeline that runs automatically

The code is all on GitHub. Start with unit tests (fast feedback), add integration tests when your module is stable, and invest in E2E tests when managing multiple environments.

**And please: always, always use `defer terraform.Destroy()`**. Future you will thank you. Future your-team will be even more grateful.

---

## Resources

- **Full code:** [Link to GitHub repo](https://github.com/elorm116/30-days-terraform/tree/main/Day-18)
- **Book reference:** *Terraform: Up & Running* by Yevgeniy Brikman, Chapter 9
- **Terratest docs:** https://terratest.gruntwork.io/
- **Terraform testing docs:** https://developer.hashicorp.com/terraform/language/tests

---

*This is part of my 30-Day Terraform Challenge journey. Follow along as I go from zero to Terraform expert in one month.*
