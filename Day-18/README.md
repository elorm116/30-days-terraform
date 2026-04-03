# Day 18 — Terraform Testing: Unit Tests + Integration Tests + CI/CD

Part of the [30 Day Terraform Challenge](https://github.com).

This day demonstrates **comprehensive testing strategies** for Terraform infrastructure code:
- **Unit tests** using Terraform native testing framework (`tftest.hcl`) with mock providers
- **Integration tests** in Go using Terratest framework
- **CI/CD automation** with GitHub Actions

## What This Demonstrates

### Terraform Native Tests (Unit Tests)
- Mock AWS providers to avoid real infrastructure costs
- Test configuration intent (does the code intend to create the right resources?)
- Run in seconds with no credentials needed
- 13 test cases covering:
  - Auto Scaling Group naming and configuration
  - Launch template instance types
  - Security group ingress/egress rules
  - Load balancer health checks
  - Environment-specific configuration (dev/production)
  - Invalid input validation

### Go Integration Tests
- Deploy real infrastructure to AWS
- Verify actual behavior (does it ACTUALLY work?)
- Automatic cleanup via `defer terraform.Destroy()`
- Test HTTP connectivity, health checks, and resource attributes
- ~10 minute runtime (includes ASG warm-up)

### CI/CD Pipeline
- Automated testing on every PR and push
- Unit tests on PRs (fast, ~30 seconds)
- Integration tests on `main` branch (after unit tests pass)
- Automatic resource cleanup prevents orphaned infrastructure

## Running Tests

### Unit Tests (Local)
```bash
cd Day-18/modules/services/webserver-cluster
terraform init
terraform test
```
**Runtime:** ~30 seconds  
**Cost:** Free  
**Runs on:** Every commit (GitHub Actions)

### Integration Tests (Local)
```bash
cd Day-18/test
go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```
**Runtime:** 9-10 minutes  
**Cost:** ~$0.50 per run  
**Runs on:** Pushes to main branch (GitHub Actions)

### End-to-End Tests (Local)
```bash
cd Day-18/test
go test -v -timeout 30m -run TestWebserverClusterEndToEnd ./...
```
**Runtime:** 25-30 minutes  
**Cost:** ~$4.50 per run (deploys 3 environments)  
**Runs on:** Manually (or weekly scheduled)

### Running GitHub Actions Manually (For Learning)

To manually trigger the workflow and monitor tests in GitHub:

1. **Go to your GitHub repository**
   - Navigate to: `Actions` tab → `Terraform Tests` workflow

2. **Click "Run workflow"** button
   - Select branch: `main`
   - Click "Run workflow"

3. **Monitor in real-time:**
   - Watch the unit tests complete (~30s)
   - Integration tests auto-start after unit tests pass (~10 min)
   - Check logs for any failures

4. **View detailed logs:**
   - Click on each job to see full terraform output
   - Check AWS resources being created/destroyed
   - Verify all tests passed before cleanup

**Example workflow run:** Shows unit tests (13/13 pass) → integration test (PASS) → cleanup (resources destroyed)

---

## CI/CD Pipeline
    ├── webserver_cluster_test.go   # Go integration tests
    ├── go.mod
    └── go.sum
```

## Prerequisites

### For Unit Tests
- Terraform >= 1.14 (native testing framework)
- No AWS credentials needed

### For Integration Tests
- Go 1.20+
- AWS credentials (`AWS_PROFILE` environment variable recommended)
- Terraform >= 1.14

### For CI/CD
- GitHub repository with Actions enabled
- AWS credentials stored as repository secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_DEFAULT_REGION`

## Running Tests Locally

### Unit Tests Only (Mock Provider, Free)

```bash
cd Day-18/modules/services/webserver-cluster

# Run all tests
terraform test

# Run specific test
terraform test -filter="validate_asg_name_prefix"
```

**Output:**
```
Success! 13 passed, 0 failed.
```

**Cost:** $0 | **Duration:** ~10-30 seconds | **AWS credentials:** Not required

### Integration Tests (Real AWS Infrastructure)

```bash
cd Day-18/test

# Ensure AWS credentials are available
export AWS_PROFILE=your-profile

# Run integration tests
go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```

**What happens:**
1. Creates real infrastructure in AWS (EC2, ALB, ASG, SGs)
2. Waits for Auto Scaling Group to stabilize (~3-5 min)
3. Tests HTTP health checks
4. Automatically destroys all resources (`defer terraform.Destroy()`)

**Output:**
```
=== RUN   TestWebserverClusterIntegration
--- PASS: TestWebserverClusterIntegration (563.42s)
PASS
ok      terraform-tests 563.42s
```

**Cost:** ~$1-2 (EC2 + ALB + data transfer) | **Duration:** ~10 minutes

## Test Cases

### Unit Tests (tftest.hcl)

| Test | Purpose | Type |
|------|---------|------|
| `validate_asg_name_prefix` | ASG uses name prefix for blue/green | Plan |
| `validate_launch_template_instance_type` | Launch template has correct instance type | Plan |
| `validate_alb_sg_port` | ALB SG allows inbound port 80 | Plan |
| `validate_web_sg_server_port` | Instance SG allows port 8080 from ALB | Plan |
| `validate_elb_health_check_type` | Health check type is ELB | Plan |
| `validate_dev_instance_type_from_locals` | Dev uses correct instance type | Plan |
| `validate_production_instance_type_from_locals` | Production uses correct instance type | Plan |
| `validate_dev_log_retention` | Dev CloudWatch logs retained 7 days | Plan |
| `validate_production_log_retention` | Production CloudWatch logs retained 30 days | Plan |
| `validate_monitoring_disabled` | Monitoring can be disabled | Plan |
| `validate_monitoring_enabled` | Monitoring can be enabled | Plan |
| `validate_bad_environment_rejected` | Invalid environment rejected | Plan (expect error) |
| `validate_bad_instance_type_rejected` | Invalid instance type rejected | Plan (expect error) |

### Integration Tests (Go)

- `TestWebserverClusterIntegration`: 
  - Deploys full stack to AWS
  - Verifies ALB responds with 200 status
  - Confirms ASG instance count
  - Validates CloudWatch logs created

## CI/CD Workflow

See [`.github/workflows/terraform-test.yaml`](.github/workflows/terraform-test.yaml).

### On PR / Push to Any Branch
```yaml
Unit Tests (tftest.hcl)
  ├─ Mock provider, no AWS resources
  └─ ~30 seconds
```

### On Push to Main (After Unit Tests Pass)
```yaml
Integration Tests (Go)
  ├─ Real AWS infrastructure
  ├─ Auto-cleanup via defer terraform.Destroy()
  └─ ~10 minutes
```

## Common Issues & Solutions

### Unit Tests Failing: "invalid index" on security groups
**Cause:** `ingress` is a set in Terraform, not a list  
**Solution:** Use `anytrue()` with `for` expression to check any ingress rule matches instead of indexing `[0]`

### Integration Tests Leave Resources Running
**Cause:** Go test process crashed before `defer terraform.Destroy()` executed  
**Solution:** Remove state lock file and re-run: `rm -f .terraform.lock.hcl && go test ...`

### Mock Provider Returns "Unknown" Values
**Cause:** Some computed attributes only become known during actual `apply`  
**Solution:** Run the test with `command = apply` in an isolated state block

### CI/CD Tests Timeout
**Cause:** ASG takes longer than expected to stabilize  
**Solution:** Increase `-timeout` flag in `go test` command (default 30m)

## Gitignore Strategy

**Committed (shared with team):**
- `webserver_cluster_test.tftest.hcl` (unit test definitions)
- `webserver_cluster_test.go` (integration test code)
- `.terraform.lock.hcl` (provider version lock)
- `.github/workflows/` (CI/CD pipeline)

**Not committed (ignored):**
- `terraform.tfstate*` (infrastructure state)
- `.terraform/` (provider plugins)
- `.terraform.lock.info` (temporary lock file)
- `terraform.tfvars` (sensitive variables)
- `backend.hcl` (backend configuration)

## Cost Considerations

| Test Type | Cost | When to Run |
|-----------|------|------------|
| Unit Tests | $0 | Every commit |
| Integration Tests | ~$1-2 | Main branch only |
| Manual inspection | $0-X | Ad hoc |

**Recommendation:** Run unit tests on every PR. Run integration tests only on `main` branch after code review to minimize costs while maintaining confidence.

## Next Steps

1. **Add more test cases** — Consider edge cases specific to your infrastructure
2. **Terraform Cloud integration** — Use `terraform cloud` for remote state + runs
3. **Performance testing** — Measure ASG scale-up times under load
4. **Disaster recovery** — Test failover and backup restore procedures

## Resources

- [Terraform Native Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Terratest Documentation](https://terratest.gruntwork.io/)
- [GitHub Actions Workflows](https://docs.github.com/en/actions/using-workflows)
