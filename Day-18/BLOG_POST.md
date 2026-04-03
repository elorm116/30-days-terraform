# Automating Terraform Testing: From Unit Tests to End-to-End Validation

**Date:** April 4, 2026  
**Author:** Anthony Zottor  
**Published on:** [Your Blog/Medium]

## Introduction

Infrastructure as Code is only as good as the tests that validate it. Yet many teams still deploy infrastructure with minimal testing — relying on manual `terraform plan` reviews and hoping nothing breaks in production.

The result? Costly runtime failures, unexpected configuration drift, and teams afraid to refactor. Worse, it doesn't scale. The moment your infrastructure grows beyond what one person can review in an afternoon, you need **automated tests that run on every change**.

Today, I'm sharing what I learned building a complete testing pipeline for Terraform modules: three test layers, the tools for each, and a CI/CD workflow that ties it all together. This is Chapter 9 of my 30-Day Terraform Challenge journey.

## Why Test Infrastructure?

Testing infrastructure is fundamentally different from testing applications:

- **Application tests** verify logic in isolation (unit tests) and integration (running services). They're fast and free.
- **Infrastructure tests** must verify *configuration*, *behavior*, and *interactions* across cloud APIs, IAM, networking, and storage. They're slow and expensive.

Yet the payoff is huge:

1. **Catch configuration errors before deployment** — Prevent misconfigured security groups, missing IAM permissions, or invalid variable combinations.
2. **Prevent regressions** — Refactor confidently knowing tests will catch breaking changes.
3. **Enable team scaling** — Junior engineers can make changes without fear, because tests prove correctness.
4. **Reduce operational burden** — Fewer incidents, faster incident resolution, more time building.

## Three Layers of Terraform Testing

### Layer 1: Unit Tests with `terraform test`

**What it tests:** Configuration syntax, logical correctness, default values — without deploying anything.

**Tool:** Native Terraform 1.6+ testing framework using `.tftest.hcl` files.

**Trade-offs:**
- ✅ Fast (seconds)
- ✅ Free (no AWS charges)
- ✅ No external dependencies
- ❌ Tests plan only, not apply
- ❌ Doesn't catch IAM or quota issues
- ❌ Boolean assertions only (limited expressiveness)

**Example:**
```hcl
run "validate_asg_name_prefix" {
  command = plan
  
  variables {
    cluster_name  = "test-cluster"
    min_size      = 1
    max_size      = 2
    environment   = "dev"
  }
  
  assert {
    condition     = aws_autoscaling_group.web.name_prefix == "test-cluster-"
    error_message = "ASG name prefix must match cluster_name variable"
  }
}
```

**When to run:** Every PR, on every commit (takes ~30 seconds).

### Layer 2: Integration Tests with Terratest

**What it tests:** Real infrastructure behavior. Deploy a module, verify outputs, check application health, then tear down.

**Tool:** Terratest (Go library). Executes `terraform init`, `terraform apply`, and HTTP requests against live AWS resources.

**Trade-offs:**
- ✅ Catches IAM, networking, quota issues
- ✅ Tests full module (plan + apply)
- ✅ Verifies real AWS behavior
- ✅ Tests application health (HTTP 200 from ALB)
- ❌ Slow (5-15 minutes per test)
- ❌ Expensive ($1-3 per test in AWS credits)
- ❌ Flaky (ALB takes time to register instances, IAM propagation delays)

**Example:**
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
  
  defer terraform.Destroy(t, terraformOptions)  // Critical cleanup
  terraform.InitAndApply(t, terraformOptions)
  
  // Verify application is accessible
  albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
  http_helper.HttpGetWithRetry(t, fmt.Sprintf("http://%s", albDnsName), 
    nil, 200, "Hello", 30, 10*time.Second)
}
```

**When to run:** Every push to main (after unit tests pass). Not on PRs (too slow, too expensive).

### Layer 3: End-to-End Tests with Terratest

**What it tests:** Full deployment pipeline across multiple environments, validating system-wide behavior.

**What makes it "E2E":**
- Deploys across *all* environments (dev → staging → production)
- Tests environment progression (dev has fewer instances, staging enables monitoring, prod uses bigger instances)
- Verifies cross-environment consistency and policies
- Tests the full application path through all tiers

**Trade-offs:**
- ✅ Validates production readiness
- ✅ Catches environment-specific bugs
- ✅ Tests organizational policies
- ❌ Very slow (15-30 minutes for 3 environments)
- ❌ Very expensive ($3-5 per run in AWS credits)
- ❌ Often skipped (overkill for every commit)

**Example from my implementation:**
```go
func TestWebserverClusterEndToEnd(t *testing.T) {
  environments := map[string]map[string]interface{}{
    "dev": {
      "cluster_name":  "e2e-test-dev",
      "min_size":      1,
      "max_size":      2,
      "enable_monitoring": false,
    },
    "staging": {
      "cluster_name":  "e2e-test-staging",
      "min_size":      2,
      "max_size":      4,
      "enable_monitoring": true,
    },
    "production": {
      "cluster_name":  "e2e-test-prod",
      "min_size":      2,
      "max_size":      6,
      "enable_monitoring": true,
    },
  }
  
  for env, vars := range environments {
    defer terraform.Destroy(t, options)
    terraform.InitAndApply(t, options)
    verifyEnvironmentOutputs(t, options, env, vars)
    verifyApplicationAccessible(t, options)
    verifyMonitoringConfig(t, options, env, vars)
  }
}
```

**When to run:** Weekly or before major releases (manually triggered or scheduled). Not on every commit.

## The Critical `defer terraform.Destroy()` Pattern

If you take one thing from this article, make it this: **always use `defer` to cleanup infrastructure.**

```go
defer terraform.Destroy(t, terraformOptions)  // Runs even if test fails
terraform.InitAndApply(t, terraformOptions)
```

Why it matters:
- Runs *even if assertions fail* (no orphaned resources)
- Runs *even if timeout occurs* (test harness still cleans up)
- Runs *first-in-last-out* across multiple environments (proper dependency ordering)

Without this? Your AWS bill will skyrocket. We've all been there: forgot the defer, test crashed, and suddenly you have 4 EC2 instances, 2 load balancers, and orphaned security groups charging $50/day that nobody remembered about. I experienced this personally during testing — it hurts.

## Test Comparison Table

| Test Layer | Tool | Deploys Real Infra | Time | Cost | What It Catches |
|---|---|---|---|---|---|
| **Unit** | `terraform test` | No | Seconds | Free | Syntax, logic, defaults, variable validation |
| **Integration** | Terratest (Go) | Yes | 5-15 min | $1-3 | IAM, networking, module behavior, app health |
| **End-to-End** | Terratest (Go) | Yes | 15-30 min | $3-5 | Environment progression, cross-env consistency, readiness |

## Building the CI/CD Pipeline

The magic happens when tests are automated. Here's my GitHub Actions workflow:

```yaml
name: Terraform Tests

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"
      
      # Set terraform variables via environment
      - name: Terraform Init, Format, Validate
        run: terraform init && terraform fmt -check && terraform validate
        working-directory: Day-18/modules/services/webserver-cluster
        env:
          TF_VAR_cluster_name: "test-cluster"
          TF_VAR_environment: "dev"
          TF_VAR_min_size: "1"
          TF_VAR_max_size: "2"
      
      - name: Run Unit Tests
        run: terraform test
        working-directory: Day-18/modules/services/webserver-cluster
        env:
          TF_VAR_cluster_name: "test-cluster"
          TF_VAR_environment: "dev"
          TF_VAR_min_size: "1"
          TF_VAR_max_size: "2"

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    needs: unit-tests
    
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION: us-east-1
      TF_VAR_cluster_name: "test-cluster"
      TF_VAR_environment: "dev"
      TF_VAR_min_size: "1"
      TF_VAR_max_size: "2"
    
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
1. **Unit tests on every PR** → Fast feedback (30 sec), catch obvious bugs before expensive tests
2. **Integration tests only on main** → Expensive, so only for "blessed" code that unit tests passed
3. **Environment variables for test config** → No hardcoded credentials, no committed `.tfvars` files
4. **Go module caching** → Speeds up integration test phase by 2-3 minutes
5. **AWS credentials in GitHub Secrets** → Never commit them, use IAM roles or temporary credentials

## Challenges I Faced (and Fixes)

### Challenge 1: Security Groups Don't Have Indexable Ingress Rules

**Error:** `Invalid index: Elements of a set are identified only by their value`

**Root cause:** Terraform defines security group ingress as a *set* (unordered), not a *list*. You can't index into sets like `ingress[0]`.

**Fix:** Use `anytrue()` with `for` expression:
```hcl
assert {
  condition = anytrue([
    for rule in aws_security_group.alb.ingress :
    rule.from_port == 80 && rule.to_port == 80
  ])
  error_message = "ALB security group must allow port 80"
}
```

### Challenge 2: Null Outputs Break terraform.Output()

**Error:** `Error: output is null` when calling `terraform.Output()`

**Root cause:** When `enable_monitoring = false`, the `sns_topic_arn` output is null. Calling `terraform.Output()` on null fails.

**Fix:** Check a non-null output instead:
```go
// Don't do this:
snsTopic := terraform.Output(t, opts, "sns_topic_arn")  // fails if null

// Do this:
monitoringEnabled := terraform.Output(t, opts, "monitoring_enabled")
assert.Equal(t, "false", monitoringEnabled)
```

### Challenge 3: Variables Don't Reach the Destroy Phase

**Error:** `No value for required variable` during terraform destroy in GitHub Actions

**Root cause:** Terraform's native test framework doesn't always pass variables to the destroy phase in non-interactive CI/CD environments.

**Fix:** Use defense-in-depth — provide variables three ways:
1. **In .tftest.hcl** (every run block)
2. **As env vars** (TF_VAR_* in workflow)
3. **With defaults** (variables.tf)

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

```yaml
env:
  TF_VAR_cluster_name: "test-cluster"
  TF_VAR_min_size: "1"
```

Any one layer catching the variable ensures destroy works.

### Challenge 4: Previous Test Runs Leave Resources Running

**Error:** Manually terminated 4 EC2 instances, 2 load balancers, 4 security groups

**Root cause:** Test process crashed before reaching `defer terraform.Destroy()`, or state file was locked.

**Fix:** Use these safeguards:
1. **Always `defer` cleanup** before any infrastructure deploys
2. **Test locally first** before trusting GitHub Actions
3. **Set strict test timeouts** (30m) to avoid runaway processes
4. **Add a scheduled AWS cleanup job** (cloud-nuke) as a safety net
5. **Tag all test resources** (ManagedBy=TerraformTest, TTL=4h) so cloud-nuke can target them

## Key Learnings

### Unit vs Integration vs E2E

The author's critique was right: **you need all three layers, but you use them differently.**

- **Unit tests** catch the obvious stuff fast. Run them constantly.
- **Integration tests** catch the subtle bugs. Run them before merging.
- **E2E tests** catch the "I forgot to configure staging differently than dev" bugs. Run them weekly or before releases.

Skipping any layer is penny-wise, pound-foolish. I learned this the hard way when I skipped unit tests and a syntax error made it past integration tests (which tested only plan, not apply). E2E caught it, but by then I'd wasted an hour.

### Why E2E Tests Matter

E2E tests aren't just "multiple integration tests." They're validating *system-wide consistency* — things you can't test in isolation:

- Does dev have fewer instances than staging? (Yes → scale properly)
- Does production enable monitoring when dev doesn't? (Yes → ops readiness)
- Can you deploy the exact same module code to all three environments? (Yes → code reusability)

This is what separates "I tested the code" from "I tested the deployment pipeline."

### The Cost Reality

Here's what I'll pay for this pipeline:

- **Unit tests:** $0 (no AWS resources)
- **Integration tests:** ~$0.50/run × 5 runs/day × 22 work days = ~$55/month
- **E2E tests:** ~$4/run × 1 run/week × 4 weeks = ~$16/month
- **Total:** ~$70/month for confidence

That's less than one incident. It's worth it.

## What's Next

You're now equipped to:
1. Write unit tests for any Terraform module in seconds
2. Build integration tests that deploy real infrastructure and verify it
3. Orchestrate E2E tests that validate environment progression
4. Build a GitHub Actions pipeline that runs automatically

The code is all on GitHub. Start with unit tests (fast feedback), add integration tests when your module is stable, and invest in E2E tests when managing multiple environments.

And please: **always, always use `defer terraform.Destroy()`**. Future you will thank you.

---

**Want to learn more?**
- Read the full code: [Link to GitHub repo]
- Book reference: *Terraform: Up & Running* by Yevgeniy Brikman, Chapter 9
- Terratest docs: https://terratest.gruntwork.io/

What test layer would you add first to your infrastructure? Share in the comments below!

---

*This is part of my 30-Day Terraform Challenge journey. Follow along as I go from zero to Terraform expert.*
