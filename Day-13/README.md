# Day 13 — Managing Sensitive Data Securely in Terraform

Part of the [30 Day Terraform Challenge](https://github.com).

Demonstrates the three secret leak paths in Terraform and how to
close each one using AWS Secrets Manager and sensitive value handling.

## Advanced Guide (priority)

- See [ADVANCED_SECRETS_MANAGEMENT_GUIDE.md](ADVANCED_SECRETS_MANAGEMENT_GUIDE.md) for a practical, multi-cloud reference: leak paths, AWS Secrets Manager + Vault patterns, env-var credential handling, state security checklist, `.gitignore`, and a least-privilege IAM policy template.

## What This Demonstrates

- The three ways secrets leak in Terraform configurations
- AWS Secrets Manager integration pattern
- sensitive = true — what it does and what it doesn't do
- State file plaintext storage — live proof
- State file security checklist

## The Three Leak Paths
```
Leak 1 — Hardcoded in .tf files
         → Use Secrets Manager data source instead

Leak 2 — Variable with default value
         → No defaults on sensitive variables, inject via TF_VAR_*

Leak 3 — State file plaintext storage
         → Encrypt + version + restrict access to S3 state bucket
```

## Prerequisites

- Terraform >= 1.10
- AWS CLI configured
- S3 bucket for remote state (`dark-knight-terraform-state`)
- AWS Secrets Manager secret created manually (see setup below)

## Setup

### Create the secret manually first
```bash
aws secretsmanager create-secret \
  --name "day13/db/credentials" \
  --secret-string '{"username":"dbadmin","password":"YourSecurePassword"}'
```

### Deploy
```bash
cd Day-13/secrets-demo
terraform init -backend-config=backend.hcl
terraform apply
```

### Prove the state file contains plaintext secrets
```bash
aws s3 cp s3://dark-knight-terraform-state/day13/secrets-demo/terraform.tfstate - \
  | grep -i password
```

### Destroy
```bash
terraform destroy

aws secretsmanager delete-secret \
  --secret-id "day13/db/credentials" \
  --force-delete-without-recovery
```

## What sensitive = true Does

| Behaviour | sensitive = true |
|---|---|
| Hides in plan/apply output | ✅ |
| Hides in CI/CD logs | ✅ |
| Prevents state file storage | ❌ |
| Encrypts the value | ❌ |
| Prevents terraform output reveal | ❌ |

## State File Security Checklist

- [ ] S3 encryption enabled (`encrypt = true`)
- [ ] Bucket versioning enabled
- [ ] Public access blocked (all 4 settings)
- [ ] IAM access restricted to Terraform execution roles
- [ ] No .terraform/, *.tfstate, *.tfvars in .gitignore

## .gitignore
```
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.backup
*.tfvars
backend.hcl
*.pem
*.key
```

## Notes

- Never create bootstrap secrets through Terraform
- Never put secrets in variable defaults
- sensitive = true is a display filter not a security control
- The state file is the last line of defence — secure it properly