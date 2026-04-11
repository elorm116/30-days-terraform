# Day 25 — Static Website on S3 + CloudFront

Deploy a production-grade static website using S3, CloudFront, and Route53 (optional custom domain).

## 📁 Project Structure

```
day25-static-website/
├── modules/
│   └── s3-static-website/       # Reusable module — all resource logic
│       ├── main.tf              # S3, CloudFront, Route53 resources
│       ├── variables.tf         # 14 input variables
│       └── outputs.tf           # 10 outputs
├── envs/
│   ├── dev/                     # Dev environment — cheap, minimal
│   │   ├── main.tf              # Module call with dev values
│   │   ├── variables.tf         # Variable declarations
│   │   ├── outputs.tf           # Output passthrough
│   │   ├── provider.tf          # AWS provider config
│   │   ├── backend.tf           # S3 remote state config
│   │   ├── terraform.tfvars     # Dev input values
│   │   └── templates/
│   │       ├── index.html.tftpl # Homepage template
│   │       └── error.html.tftpl # 404 error page
│   └── production/              # Production — global CDN, custom domain, logging
│       ├── main.tf              # Module call with prod values
│       ├── variables.tf         # Variable declarations
│       ├── outputs.tf           # Output passthrough
│       ├── provider.tf          # AWS provider config
│       ├── backend.tf           # S3 remote state config
│       ├── terraform.tfvars     # Prod input values
│       └── templates/
│           ├── index.html.tftpl # Homepage template
│           └── error.html.tftpl # 404 error page
└── scripts/
    └── invalidate-cache.sh      # CloudFront cache invalidation helper
```

## 🚀 Quick Start

### Prerequisites
- AWS account with credentials configured
- Terraform 1.5+
- AWS CLI v2 configured
- (Optional) Route53 hosted zone for custom domain

### Deploy Dev Environment

```bash
cd envs/dev/
terraform init
terraform plan
terraform apply
```

### Deploy Production Environment

```bash
cd envs/production/

# Optionally set custom domain variables
export TF_VAR_custom_domain="example.com"
export TF_VAR_acm_certificate_arn="arn:aws:acm:us-east-1:..."
export TF_VAR_route53_zone_id="Z123456789ABC"

terraform init
terraform plan
terraform apply
```

## 📡 Access Your Website

After deployment, use the CloudFront URL from outputs:

```bash
terraform output cloudfront_domain_name
```

For production with custom domain:

```bash
terraform output custom_domain_url
```

## 🔄 Update Website Content

1. **Modify HTML templates** in `envs/{dev|production}/templates/`
2. **Reapply Terraform:**

```bash
terraform apply
```

3. **Invalidate CloudFront cache** so changes appear immediately:

```bash
# Using the helper script
./scripts/invalidate-cache.sh <distribution-id>

# Or manually with AWS CLI
aws cloudfront create-invalidation \
  --distribution-id E1234EXAMPLE \
  --paths '/*'
```

## 📊 Architecture Overview

### Dev Environment
- **S3 Price Class:** PriceClass_100 (US + EU only) ✅ Cheapest
- **CloudFront:** Enabled, 24-hour cache
- **Logging:** Disabled (saves cost)
- **Custom Domain:** Not configured
- **TTL:** Default (3600 seconds)

### Production Environment
- **S3 Price Class:** PriceClass_All (600+ edge locations worldwide) 🌍 
- **CloudFront:** Enabled, 7-day max cache, 24-hour default
- **Logging:** Enabled for S3 + CloudFront (audit trail)
- **Custom Domain:** Supported via Route53 + ACM
- **TTL:** Longer (24 hours default, 7 days max)

## 🔐 Security

| Component | Security |
|-----------|----------|
| **S3 Bucket** | Public access blocked; only CloudFront can read via OAI |
| **CloudFront** | HTTPS enforced; HTTP redirected |
| **ACM Certificate** | Auto-renewed when using custom domain |
| **State File** | Encrypted with SSE-S3; locked via DynamoDB |

## 💰 Cost Estimation

### Dev (monthly)
- S3 storage: $0.023 per GB
- CloudFront: ~$0.085 per GB (PriceClass_100)
- **Estimated:** $1–5 for modest traffic

### Production (monthly)
- S3 storage: $0.023 per GB
- CloudFront: ~$0.085 per GB (PriceClass_All gets cheaper rate on volume)
- Route53: $0.50 per hosted zone + query fees
- CloudFront logging: ~$0.01 per 1M requests
- **Estimated:** $5–20+ depending on traffic

*Note: Unused resources can be destroyed with `terraform destroy` to avoid charges.*

## 📝 Variables Reference

### Dev & Production (Shared)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `bucket_name` | string | — | S3 bucket name (globally unique, 3–63 chars) |
| `environment` | string | `dev` | Environment name (dev/staging/production) |
| `index_document` | string | `index.html` | Root document served at `/` |
| `error_document` | string | `error.html` | 404 error page |
| `cloudfront_price_class` | string | `PriceClass_100` | CDN edge coverage (100/200/All) |

### Production Only

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `custom_domain` | string | `null` | Custom domain (e.g., example.com) |
| `acm_certificate_arn` | string | `null` | ACM cert ARN in us-east-1 |
| `route53_zone_id` | string | `null` | Route53 hosted zone ID |

## 🎯 Outputs

```hcl
bucket_name              # S3 bucket name
cloudfront_domain_name   # CloudFront URL (primary access point)
cloudfront_distribution_id # ID for cache invalidations
custom_domain_url        # Custom domain URL (production only)
invalidation_command     # AWS CLI command to invalidate cache
```

## 🔧 Troubleshooting

### CloudFront shows old content after update
→ Invalidate the cache with `./scripts/invalidate-cache.sh <dist-id>`

### S3 bucket name already exists
→ Bucket names are globally unique. Change `bucket_name` in `terraform.tfvars`

### Custom domain returns 403 Forbidden
→ Ensure ACM certificate is in **us-east-1** and Route53 A record points to CloudFront

### State lock timeout
→ The DynamoDB table `terraform-locks` is in use. Check for stuck applies: `aws dynamodb delete-item --table-name terraform-locks --key 'LockID={S=day-25/...}'`

## 🎓 Learning Points

1. **Module Reuse:** One module (`s3-static-website`) deployed across dev & production
2. **DRY Principle:** Logic centralized; only variable values differ per environment
3. **CloudFront:** CDN caching, OAI (Origin Access Identity), invalidation strategies
4. **Terraform Templating:** `templatefile()` renders HTML with environment-specific vars
5. **Remote State:** S3 backend ensures collaborative infrastructure management

## 📚 Resources

- [AWS S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront Distributions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-overview.html)
- [Terraform AWS S3 Bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
- [Terraform CloudFront Distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)

## 🧹 Cleanup

Destroy all resources when done:

```bash
# From envs/dev/ or envs/production/
terraform destroy
```

**Warning:** This deletes the S3 bucket and CloudFront distribution. Back up any critical data first.
