# Terraform 3-Layer Testing System — Complete Technical Deep Dive

Companion technical guide to the blog post: *"I Stopped Trusting Terraform Apply — So I Built a 3-Layer Testing System"*

This document walks through the full implementation, real code, hard lessons, and practical solutions from Day 18 of my #30DaysOfTerraform challenge.

---

## Who This Is For

- Engineers who are comfortable writing Terraform modules
- Teams managing multiple environments (dev, staging, production)
- Anyone tired of "it worked in plan, but broke in production"

If you're completely new to Terraform, start with basic module writing first.

---

## The $8 Lesson That Started It All

One failed Terratest run due to a CloudWatch quota error left real infrastructure running:

- 4 EC2 instances
- 2 load balancers
- Multiple security groups

**Result:** +$8 bill and 6 hours of cleanup stress.

That incident made it crystal clear:  
**Testing without reliable cleanup and multiple validation layers is just expensive hope.**

This guide shows exactly how I solved it.

---

## Recommended Phased Rollout

| Phase | Focus | Time/Cost | Expected Impact |
|-------|-------|-----------|-----------------|
| **Week 1** | Native unit tests | Free / 30s | Catch logic & config errors |
| **Week 2** | One solid integration test | ~$0.50 / 10m | Validate real AWS behavior |
| **Week 3** | Basic E2E coverage | ~$5 / 30m | Ensure multi-environment safety |

---

## The 3-Layer Testing Pyramid

```
Unit Tests (terraform test)          ← Configuration logic & intent
          ↓
Integration Tests (Terratest)        ← Real AWS deployment + behavior
          ↓
End-to-End Tests                     ← Cross-environment consistency
```

Each layer answers a different question:

- **Unit:** "Does the code make sense?"
- **Integration:** "Does it actually work when deployed?"
- **E2E:** "Does the same code behave correctly everywhere?"

---

## Layer 1: Unit Tests (terraform test)

**File:** `modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl`

13 tests that run in ~30 seconds using mocked providers.

### Key Example – ALB Security Group

```hcl
assert {
  condition = anytrue([
    for rule in aws_security_group.alb_sg.ingress :
    rule.from_port == 80 && rule.protocol == "tcp"
  ])
  error_message = "ALB must allow HTTP traffic on port 80"
}
```

**Important Terraform Gotcha:**  
`ingress` and `egress` are sets, not lists. Indexing (`[0]`) will fail. Always use `for` expressions with `anytrue()` or `length()`.

### The 13 Unit Tests Cover:

1. `validate_asg_name_prefix` — ASG naming conventions
2. `validate_launch_template_instance_type` — Instance type correctness
3. `validate_alb_sg_port` — ALB security group port rules
4. `validate_web_sg_server_port` — Web server security group rules
5. `validate_elb_health_check_type` — ELB health check configuration
6. `validate_dev_instance_type_from_locals` — Dev environment instance type
7. `validate_production_instance_type_from_locals` — Production instance type
8. `validate_dev_log_retention` — Dev log retention (7 days)
9. `validate_production_log_retention` — Production log retention (30 days)
10. `validate_monitoring_disabled` — Monitoring disabled in dev
11. `validate_monitoring_enabled` — Monitoring enabled in production
12. `validate_bad_environment_rejected` — Invalid environment rejection
13. `validate_bad_instance_type_rejected` — Invalid instance type rejection

**Run:**

```bash
cd modules/services/webserver-cluster
terraform init
terraform test -verbose
```

---

## Layer 2: Integration Tests (Terratest)

**File:** `test/webserver_cluster_test.go` (Function: `TestWebserverClusterIntegration`)

This test deploys the full stack, verifies the ALB is serving traffic, and guarantees cleanup.

**Critical Pattern:**

```go
defer terraform.Destroy(t, terraformOptions)
```

**Common Pitfall – Null Outputs:**

```go
// Bad: crashes if output is null
snsArn := terraform.Output(t, terraformOptions, "sns_topic_arn")

// Good: assert on the control flag instead
monitoringEnabled := terraform.Output(t, terraformOptions, "monitoring_enabled")
assert.Equal(t, "false", monitoringEnabled)
```

**Run:**

```bash
cd test
go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```

---

## Layer 3: End-to-End Tests

**File:** `test/webserver_cluster_e2e_test.go` (Function: `TestWebserverClusterEndToEnd`)

Deploys the module to dev → staging → production sequentially with environment-specific variables to validate consistency and conditional logic.

**Run:**

```bash
cd test
go test -v -timeout 30m -run TestWebserverClusterEndToEnd ./...
```

---

## Real Challenges & How They Were Solved

### Security Group Indexing Error

**Root cause:** Sets have no guaranteed order.

**Fix:** `anytrue()` + `for` expression.

### Variables Disappearing During Destroy in CI

**Fix:** Multi-layer approach (variables {} block + `TF_VAR_*` + defaults in `variables.tf`).

### Terratest Crashing on Null Outputs

**Fix:** Assert on control flags instead of optional outputs.

### ALB / ASG Warm-up Delays

**Fix:** Smart retry logic with `HttpGetWithRetryWithCustomValidation()` (30 attempts × 10s).

---

## GitHub Actions Setup

- Manually triggered (workflow_dispatch)
- Fail-fast: Unit tests first
- Proper variable injection via TF_VAR_*
- Go module caching

---

## Cost & Performance Summary

| Layer | Duration | Approx. Cost | Recommended Frequency |
|-------|----------|--------------|----------------------|
| **Unit** | 30 seconds | $0 | Every PR |
| Integration | 9–10 minutes | ~$0.50 | Merge to main |
| E2E | 27–30 minutes | ~$4.50 | Weekly |

**Total monthly cost for regular testing:** ~$60–80

---

## Final Takeaways

- `terraform apply` is not a test.
- Reliable cleanup (`defer terraform.Destroy()`) is non-negotiable.
- One testing layer is never enough.
- Good testing infrastructure pays for itself many times over in time, money, and peace of mind.

---

All code is in the repository. Fork it, break it, improve it.

Questions or want to adapt this for your own use case? Feel free to open an issue.

Happy testing! 🚀
