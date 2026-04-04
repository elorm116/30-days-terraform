# Day 18 — Terraform Testing Mastery: Unit + Integration + E2E

Part of my **[30 Days of Terraform Challenge](https://github.com/elorm116/30-days-terraform)**.

This repo demonstrates a **complete 3-layer testing strategy** for Terraform infrastructure code — moving from *"hoping it works"* after `terraform apply` to **knowing it works** with confidence.

### The 3 Layers

| Layer              | Tool                  | Time       | Cost     | Purpose                                      | Frequency              |
|--------------------|-----------------------|------------|----------|----------------------------------------------|------------------------|
| **Unit**           | `terraform test`      | ~30s       | $0       | Validate configuration logic & intent        | Every PR / commit      |
| **Integration**    | Terratest (Go)        | 9–10 min   | ~$0.50   | Deploy real AWS infra + verify behavior      | On merge to main       |
| **End-to-End**     | Terratest (Go)        | 25–35 min  | ~$4.50   | Test across dev, staging & production        | Weekly / pre-release   |

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
│   └── webserver_cluster_test.tftest.hcl     # 13 native unit tests
├── test/
│   ├── webserver_cluster_test.go             # Integration tests
│   ├── webserver_cluster_e2e_test.go         # End-to-End tests
│   └── go.mod
├── docs/
│   └── technical-deep-dive.md                # Full detailed guide
└── .github/workflows/
    └── terraform-test.yaml                   # CI/CD pipeline (at repo root)
```

---

## Running the Tests

### Unit Tests
Uses mock AWS provider — no credentials or cost required. Covers 13 test cases including security groups, environment logic, and input validation.

### Integration Tests
Deploys real infrastructure (ALB + ASG + EC2), performs HTTP health checks, and automatically cleans up using `defer terraform.Destroy()`.

### End-to-End Tests
Deploys the same module to dev, staging, and production with different configurations to catch environment-specific bugs.

---

## Common Challenges & Solutions

- **"Invalid index" on security groups** → `ingress`/`egress` is a set, not a list. Use `anytrue()` + for expression.
- **Variables missing during destroy in CI** → Use defense-in-depth: variables block in `.tftest.hcl` + `TF_VAR_*` env vars + defaults in `variables.tf`.
- **Null outputs crashing Terratest** → Assert on feature flags (`monitoring_enabled`) instead of nullable outputs.
- **ALB takes 2–3 minutes to become healthy** → Use `HttpGetWithRetryWithCustomValidation()` with proper retries.

---

## CI/CD with GitHub Actions

The pipeline is **manually triggered** (to control costs) and follows a fail-fast pattern:

1. Unit tests run first (~30 seconds)
2. Integration tests run only if unit tests pass
3. Full cleanup is guaranteed

### How to trigger manually:

- Go to **Actions** tab in this repository
- Select **"Terraform Tests"** workflow
- Click **"Run workflow"**

See: [.github/workflows/terraform-test.yaml](../../.github/workflows/terraform-test.yaml) (at repository root)

---

## Prerequisites

- Terraform ≥ 1.10
- Go ≥ 1.21 (for integration & E2E tests)
- AWS credentials (only needed for integration/E2E tests)

---

## What I Learned

- `terraform apply` is not testing
- `defer terraform.Destroy()` is the most important line in any integration test
- Multiple testing layers are essential — each catches what the others miss
- Proper cleanup strategy prevents expensive orphaned resources

Feel free to fork, adapt, and use this as a template for your own Terraform modules!

---

## Links & Resources

- **Blog Post:** [I Stopped Trusting terraform apply — So I Built a 3-Layer Testing System](https://medium.com/@aezottor/i-stopped-trusting-terraform-apply-so-i-built-a-3-layer-testing-system-90d151de3d4c)
- **Full Technical Deep Dive:** [docs/technical-deep-dive.md](./docs/technical-deep-dive.md)
- **Terraform Testing Docs:** https://developer.hashicorp.com/terraform/language/tests
- **Terratest Documentation:** https://terratest.gruntwork.io/

---

Made with ❤️ during #30DaysOfTerraform
