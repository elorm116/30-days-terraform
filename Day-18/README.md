# Day 18 — Terraform Testing Mastery: Unit + Integration + E2E

Part of my **[30 Days of Terraform Challenge](https://github.com/elorm116/30-days-terraform)**.

This repository demonstrates a **complete 3-layer testing strategy** for Terraform infrastructure:

- **Layer 1**: Fast native Terraform unit tests (`terraform test`)
- **Layer 2**: Real AWS integration tests with Terratest (Go)
- **Layer 3**: End-to-End tests across dev, staging, and production

The goal: Move from **"hoping it works"** after `terraform apply` to **"knowing it works"** with confidence.

## Why This Matters

Most people run `terraform apply` and pray while checking the AWS console.  
I stopped doing that.

This project shows how to test Terraform code at three levels — catching bugs early, validating real behavior in AWS, and ensuring consistency across environments.

## Architecture Overview

| Layer              | Tool                  | Time       | Cost     | Purpose                              | When to Run          |
|--------------------|-----------------------|------------|----------|--------------------------------------|----------------------|
| **Unit**           | `terraform test`      | ~30s       | $0       | Validate configuration logic         | Every PR / commit    |
| **Integration**    | Terratest (Go)        | 9–10 min   | ~$0.50   | Deploy real infra + verify behavior  | Merge to main        |
| **End-to-End**     | Terratest (Go)        | 25–35 min  | ~$4.50   | Test across dev/staging/production   | Weekly / pre-release |

---

## Quick Start

### 1. Unit Tests (Fast & Free)
```bash
cd Day-18/modules/services/webserver-cluster
terraform init
terraform test -verbose
```

### 2. Integration Tests (Real AWS)
```bash
cd Day-18/test
go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```

### 3. End-to-End Tests (Multi-Environment)
```bash
cd Day-18/test
go test -v -timeout 30m -run TestWebserverClusterEndToEnd ./...
```

---

## Project Structure

```
Day-18/
├── modules/services/webserver-cluster/
│   ├── main.tf
│   ├── variables.tf
│   └── webserver_cluster_test.tftest.hcl     # ← 13 unit tests
├── test/
│   ├── webserver_cluster_test.go             # Integration test
│   ├── webserver_cluster_e2e_test.go         # End-to-End test
│   └── go.mod
└── docs/
    └── technical-deep-dive.md                # Full detailed guide

# CI/CD Pipeline (at repository root)
.github/workflows/
└── terraform-test.yaml                      # Shared workflow for Day-18 tests
```

---

## Running the Tests

### Unit Tests
Uses mock AWS provider → no credentials or costs  
13 comprehensive tests covering naming, security groups, environment logic, validation, etc.
```bash
terraform test
```

### Integration Tests
Deploys real infrastructure, performs HTTP health checks on the ALB, and cleans up automatically using `defer terraform.Destroy()`.

### End-to-End Tests
Deploys the same module to dev, staging, and production with different configurations to catch environment-specific issues.

---

## Common Challenges & Solutions

**Security group "invalid index" error** → Use `anytrue()` + for expression (sets have no order)

**Variables not available during destroy in CI** → Use `TF_VAR_*` + variables blocks + defaults

**Null outputs crashing Terratest** → Assert on feature flags instead of nullable outputs

**ALB takes time to become healthy** → Built-in retry logic (up to 5 minutes)

---

## CI/CD with GitHub Actions

**Note:** The CI/CD workflow is located at the **repository root** (`.github/workflows/terraform-test.yaml`) — not in Day-18. GitHub Actions only recognizes workflows from the `.github/` folder at the repository root.

The pipeline is **manually triggered** (to control costs and let you observe the workflow) with this flow:

1. **Unit tests run first** (~30 seconds) — fail-fast validation
2. **Integration tests run next** (if unit tests pass) — real AWS deployment
3. **Full resource cleanup guaranteed** — `defer terraform.Destroy()` runs automatically

### How to Manually Trigger

**GitHub Web UI (Easiest):**
1. Go to your repo → **Actions** tab
2. Select **"Terraform Tests"** workflow
3. Click **"Run workflow"** → Confirm branch `main` → Run

**GitHub CLI:**
```bash
gh workflow run terraform-test.yaml --ref main
```

See the workflow file: [`.github/workflows/terraform-test.yaml`](../../.github/workflows/terraform-test.yaml) (at repository root)

---

## Prerequisites

- Terraform ≥ 1.10
- Go ≥ 1.21 (for integration tests)
- AWS credentials (for integration/E2E tests only)

---

## Next Steps & Learnings

This project taught me that:

- `terraform apply` is not testing
- `defer terraform.Destroy()` is sacred
- Multiple testing layers are essential
- Cleanup strategy matters more than most people realize

Feel free to fork, adapt, and improve it!

---

## Links

- **Blog Post:** [I Stopped Trusting terraform apply — So I Built a 3-Layer Testing System](https://medium.com/@aezottor/i-stopped-trusting-terraform-apply-so-i-built-a-3-layer-testing-system-90d151de3d4c)
- **Full Technical Deep Dive:** [docs/technical-deep-dive.md](./docs/technical-deep-dive.md)
- **Terraform Testing Docs:** https://developer.hashicorp.com/terraform/language/tests
- **Terratest Docs:** https://terratest.gruntwork.io/

---

Made with ❤️ during #30DaysOfTerraform
