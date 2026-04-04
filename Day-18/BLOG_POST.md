# I Stopped Trusting terraform apply — So I Built a 3-Layer Testing System

From hoping my infrastructure works to knowing it works — with fast unit tests, real AWS integration tests, and full end-to-end validation.

## The Ritual We All Know Too Well

```bash
terraform apply
# Check AWS → see resources → assume everything works
```

That's not testing. That's hoping.

And hope gets expensive in the cloud.

It worked fine when my setups were small — one environment, a handful of resources, easy to verify manually. But as things scaled (more modules, more environments, more edge cases), silent failures started slipping through.

A plan looked perfect, yet after deployment:
- Security group rules didn't apply correctly
- IAM permissions were missing
- Staging behaved differently from production

Terraform didn't complain. It just deployed broken infrastructure.

That's when I stopped trusting `terraform apply` as validation — and built a 3-layer testing system instead.

## The Hidden Truth About Terraform

Terraform is excellent at provisioning infrastructure, but **it does not guarantee correctness**.

You can easily:
- Deploy something that looks fine in the plan but doesn't actually work
- Ship silent misconfigurations
- Break production with a seemingly harmless refactor
- Miss environment-specific bugs

Manual checks work… until they don't. Once your infrastructure grows beyond what one person can reliably verify, you need automated testing at multiple levels.

## The 3-Layer Terraform Testing System

Each layer answers a different question:

### Layer 1: Unit Tests — "Does the Code Make Sense?" ⚡

**Tool:** Native Terraform testing (terraform test with .tftest.hcl files)  
**Time:** ~30 seconds  
**Cost:** $0  
**Deploys real infrastructure:** No

These tests validate your configuration before anything touches AWS. They catch logic errors, invalid variable combinations, broken references, and incorrect resource settings early.

Example — Validating a security group rule:

```hcl
assert {
  condition = anytrue([
    for rule in aws_security_group.alb_sg.ingress :
    rule.from_port == 80 && rule.protocol == "tcp"
  ])
  error_message = "ALB security group must allow HTTP traffic on port 80"
}
```

**What they catch:**
- ✅ Syntax errors in HCL
- ✅ Invalid variable combinations
- ✅ Wrong security group rules in the plan
- ✅ Missing required attributes

**What they DON'T catch:** IAM issues, network connectivity, or application health.

**When to run:** On every PR and every commit. They're fast, free, and give immediate feedback.

---

### Layer 2: Integration Tests — "Does It Actually Work in AWS?" 🏗️

**Tool:** Terratest (Go library)  
**Time:** 9–15 minutes  
**Cost:** Low (~$0.10 – $0.50 per run)  
**Deploys real infrastructure:** Yes

This layer deploys real resources, verifies they behave as expected, and then tears them down.

It catches real-world problems like IAM permission failures, security group misconfigurations, load balancer health checks, and actual application responses (e.g., HTTP 200).

**The most important line of code:**

```go
defer terraform.Destroy(t, terraformOptions)
```

This guarantee runs even if the test fails — preventing orphaned resources and surprise AWS bills.

**When to run:** On merge to main (after unit tests pass).

---

### Layer 3: End-to-End Tests — "Does It Work Across All Environments?" 🌍

**Tool:** Terratest  
**Time:** 25–35 minutes  
**Cost:** Higher (~$1 – $5 per run)  
**Deploys real infrastructure:** Yes (multiple environments)

E2E tests deploy the same module across dev, staging, and production (with environment-specific settings) to verify consistency and catch "works in dev, breaks in prod" issues.

They validate scaling, monitoring, conditional logic, and configuration differences across environments.

**When to run:** Weekly or before major releases (manually triggered to control cost).

---

## The Smart Strategy (Choose All Three)

| Layer | Speed | Cost | Coverage | Recommended Frequency |
|---|---|---|---|---|
| **Unit** | ⚡ Very Fast | $0 | Basic | Every PR / commit |
| **Integration** | Medium | Low | Good | On merge to main |
| **End-to-End** | 🐢 Slow | Higher | Excellent | Weekly or before releases |

**Rule of thumb:** Start with unit tests (highest ROI), add integration tests next, then E2E tests once your modules mature.

Each layer compensates for the weaknesses of the others.

---

## The Real Cost of Not Testing

One broken deploy can cost hours of debugging. One orphaned resource can rack up real AWS money. One production incident can damage trust.

Compare that to:
- ~$0 for unit tests
- ~$0.10–$0.50 for integration tests
- ~$1–$5 for E2E tests

Testing isn't expensive. Not testing is.

---

## Key Takeaways

1. **`terraform apply` is not validation** — Just because it deploys doesn't mean it works
2. **Manual checks don't scale with complexity** — You need automated tests
3. **You need multiple testing layers** — Each solves a different problem
4. **Always use `defer terraform.Destroy()`** — Your future self (and AWS bill) will thank you
5. **Automated testing turns hope into confidence** — Infrastructure without tests is just controlled risk

**Final thought:** With this 3-layer system, I moved from "I think this will work" to "I know this will work" — before it ever hits production.

---

## Full Technical Implementation

Want implementation details, code examples, and troubleshooting for all the challenges we faced?

👉 **[Read the Complete Technical Writeup](https://github.com/elorm116/30-days-terraform/blob/main/Day-18/TECHNICAL_WRITEUP.md)**

This deep-dive covers:
- ✅ All 13 unit test examples with code & explanations
- ✅ Complete Terratest integration test code
- ✅ End-to-end test orchestration (dev → staging → production)
- ✅ Real challenges we solved (set indexing errors, null outputs, variable propagation)
- ✅ Complete GitHub Actions workflow with best practices
- ✅ Cost breakdown and actual timing data
- ✅ Defense-in-depth variable passing for CI/CD
- ✅ Exact execution results from our test runs

---

## What's Your Testing Pain Point?

Drop a comment — security groups, variable handling, cleanup issues, or something else?

If you found this helpful, follow along for more from my **#30DaysOfTerraform** challenge where I'm going from zero to production-grade IaC in one month.

**Happy testing!**
