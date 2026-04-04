# Terraform 3-Layer Testing System — Complete Technical Deep Dive

> Companion guide to the blog post: *"I Stopped Trusting Terraform Apply — So I Built a 3-Layer Testing System"*

This document contains the full implementation details, code, challenges, and solutions from Day 18 of my #30DaysOfTerraform challenge.

---

## Who Should Read This

Engineers who already write Terraform modules and want to move from "it looks good in plan" to production-grade confidence.

If you're still learning basic Terraform syntax, start with official tutorials first.

---

## The $8 Incident That Changed Everything

A Terratest run failed midway due to a CloudWatch quota limit.

The test exited.

The infrastructure **did not**.

Four EC2 instances, two load balancers, and several security groups kept running for 6 hours.

**Cost:** +$8  
**Lesson:** Without reliable cleanup and layered testing, you have no real control.

This guide shows the complete system I built to solve that problem.

---

## Start Small – Recommended Rollout

Don't implement everything at once.

**Week 1:** Add 5–8 native unit tests (`terraform test`)  
**Week 2:** Add one solid integration test with Terratest + `defer terraform.Destroy()`  
**Week 3:** Add basic E2E coverage for dev + production

This progression alone eliminates ~80% of common Terraform failures.

---

## The 3-Layer Testing Pyramid

```
Unit Tests (terraform test)          ← Fast, free, configuration logic
↓
Integration Tests (Terratest)        ← Real AWS + behavior verification
↓
End-to-End Tests                     ← Multi-environment consistency
```

Each layer answers a different question:
- **Unit**: "Does the code *intend* to do the right thing?"
- **Integration**: "Does it *actually* work in AWS?"
- **E2E**: "Does the same code work correctly across all environments?"

---

## Layer 1: Unit Tests (`terraform test`)

**Location:** `modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl`

Contains **13 focused tests** that run in ~30 seconds with mock providers.

### Key Examples

**Security Group Rule Validation**
```hcl
assert {
  condition = anytrue([
    for rule in aws_security_group.alb_sg.ingress :
    rule.from_port == 80 && rule.protocol == "tcp"
  ])
  error_message = "ALB security group must allow HTTP traffic on port 80"
}
```

**⚠️ Critical Gotcha (Security Groups)**
```hcl
# ❌ Never do this — ingress is a set, not a list
aws_security_group.alb_sg.ingress[0].from_port

# ✅ Correct — use anytrue() with for expression
anytrue([ for rule in aws_security_group.alb_sg.ingress : rule.from_port == 80 ])
```

**Environment-Specific Logic & Validation**

Tests for:
- Instance type per environment (t3.micro in dev → t3.small in prod)
- Log retention (7 days in dev → 30/90 days in prod)
- Monitoring enabled/disabled behavior
- Invalid input rejection (expect_failures)

**Run command:**
```bash
cd modules/services/webserver-cluster
terraform init
terraform test -verbose
```

---

## Layer 2: Integration Tests (Terratest)

**Location:** `test/webserver_cluster_test.go`

This test:
- Generates a unique cluster name
- Deploys real infrastructure
- Verifies the ALB serves HTTP 200
- Automatically cleans up using `defer terraform.Destroy()`

**Most Important Line:**
```go
defer terraform.Destroy(t, terraformOptions)
```

**Null Output Gotcha:**
Never call `terraform.Output()` on potentially null values. Check feature flags instead (monitoring_enabled).

**Run:**
```bash
cd test
go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```

---

## Layer 3: End-to-End Tests

**Location:** `test/webserver_cluster_e2e_test.go`

Deploys the same module to dev, staging, and production with different configurations to catch cross-environment bugs.

**Run:**
```bash
cd test
go test -v -timeout 30m -run TestWebserverClusterEndToEnd ./...
```

---

## Real Challenges & Solutions

### 1. Security Group Set Indexing → Solved with `anytrue()` + `for`

### 2. Variables Not Reaching Destroy Phase in CI → Defense-in-Depth
- Variables block in `.tftest.hcl`
- `TF_VAR_*` environment variables
- Defaults in `variables.tf`

### 3. Null Outputs Crashing Go Tests → Assert on Flags, Not Nullable Values

### 4. ALB Warm-up Time → Proper Retry Logic
```go
http_helper.HttpGetWithRetryWithCustomValidation(
  t, url, nil, 30, 10*time.Second,
  func(status int, body string) bool {
    return status == 200 && len(body) > 0
  },
)
```

---

## GitHub Actions CI/CD

**Manually triggered** (`workflow_dispatch`)  
**Fail-fast:** Unit → Integration  
**Full variable injection** via `TF_VAR_*`  
**Go module caching** for speed

---

## Cost & Performance

| Layer | Time | Cost | Frequency |
|-------|------|------|-----------|
| Unit | 30 seconds | $0 | Every PR |
| Integration | 9–10 minutes | ~$0.50 | Merge to main |
| E2E | 25–35 minutes | ~$4.50 | Weekly |

---

## Key Takeaways

✅ `terraform apply` is not validation  
✅ `defer terraform.Destroy()` is sacred  
✅ Multiple layers are required — each catches different classes of failures  
✅ Cleanup strategy is as important as the tests themselves  
✅ Testing pays for itself many times over  

---

**All code is in this repository. Feel free to fork and adapt it for your own modules.**

Questions or improvements? Open an issue or PR.

**Happy testing! 🚀**
