# Day 27 - Multi-Region High Availability

Day 27 builds a production-style, two-region Terraform stack for a simple web application. It deploys a full 3-tier environment in `us-east-1` and `us-west-2`, then connects the pieces with cross-region database replication, regional load balancers, and shared S3 replication.

This day is focused on high availability and recovery design rather than just resource provisioning. The key goal is to keep the application layer, database layer, and supporting storage resilient across regions.

## What Is Included

- A primary VPC in `us-east-1` and a secondary VPC in `us-west-2`.
- Separate public and private subnet layouts in each region.
- Regional Application Load Balancers for each stack.
- Auto Scaling Groups in both regions.
- An RDS MySQL primary in `us-east-1`.
- A cross-region RDS read replica in `us-west-2`.
- S3 bucket replication from primary to secondary.
- Route 53 is not used for this environment because the domain stays on Cloudflare nameservers and you do not want to switch them.

## Architecture

The production stack lives in [`envs/prod`](envs/prod) and wires together the reusable modules under [`modules`](modules).

```text
Primary region (us-east-1)
  VPC -> ALB -> ASG -> RDS primary

Secondary region (us-west-2)
  VPC -> ALB -> ASG -> RDS read replica

Shared
  S3 replication from primary to secondary
  Existing domain DNS remains on Cloudflare
```

The dependency chain is intentionally explicit in the production root module:

- `vpc_primary` feeds `alb_primary`.
- `alb_primary` feeds `asg_primary`.
- `asg_primary` feeds `rds_primary` for network access.
- `rds_primary` exports the ARN used by `rds_replica`.
- The secondary region mirrors the same layout with its own provider alias.

## Directory Layout

```text
Day-27/
  envs/prod/
    backend.tf
    main.tf
    outputs.tf
    provider.tf
    terraform.tfvars
    variables.tf
  modules/
    alb/
    asg/
    rds/
    route-53/
    vpc/
```

The root production environment is the main entry point. The modules are reusable building blocks that can be adapted for future environments.

## RDS Design Notes

The RDS module supports two modes:

- `is_replica = false` creates the primary MySQL instance.
- `is_replica = true` creates a cross-region read replica.

Two important implementation details matter here:

1. The primary database now uses a generated write-only password and publishes the credentials to a dedicated Secrets Manager secret for the application instances.
2. The replica must be created with a destination KMS key ARN. For this stack, the AWS-managed RDS key in the replica region is used.

This matters because AWS rejects cross-region MySQL replication when the source instance uses `manage_master_user_password`, and it also rejects an unencrypted destination for an encrypted source.

## Application Bootstrap

The ASG module reads the database secret at boot time and writes the credentials into a root-only file on the instance. The user data then starts Apache and serves a simple status page.

The secret is expected to contain JSON in this shape:

```json
{
  "username": "...",
  "password": "..."
}
```

## Prerequisites

- Terraform 1.10 or later.
- AWS credentials configured for both regions.
- Existing VPC/networking access for the account.
- A valid `terraform.tfvars` file in `envs/prod`.

## Deployment

From the production environment directory:

```bash
cd Day-27/envs/prod
terraform init
terraform plan -out=day27.tfplan
terraform apply day27.tfplan
```

If you are iterating on the configuration and the saved plan becomes stale, rerun:

```bash
terraform apply -auto-approve
```

## Inputs

The production stack expects values for the following major groups:

- Application identity: `app_name`, `environment`.
- Primary region networking and AMI inputs.
- Secondary region networking and AMI inputs.
- RDS sizing and credentials: `db_name`, `db_username`, `db_instance_class`, `db_allocated_storage`.
- Route 53 placeholders, if that module is re-enabled later.

Most of the current operational values live in [`envs/prod/terraform.tfvars`](envs/prod/terraform.tfvars).

## Outputs

The production environment exposes useful values for testing and downstream automation:

- `primary_alb_dns`
- `secondary_alb_dns`
- `app_name`
- `primary_db_endpoint`
- `secondary_db_endpoint`

Use the ALB DNS values to verify the app in each region once the stack is up.

## Verification

After apply, you can confirm the app in each region by curling the ALB DNS name:

```bash
terraform output primary_alb_dns
terraform output secondary_alb_dns
curl http://<alb-dns-name>
```

The response should show the region, instance ID, and basic environment banner from the EC2 user data.

## Operational Notes

- Route 53 failover is intentionally not used here because the environment stays on Cloudflare nameservers.
- The primary database must stay encrypted for the replica path to work.
- Cross-region RDS replica creation can take several minutes even when the configuration is correct.
- The secondary ASG is currently wired to the primary DB secret. In a real failover runbook, that should be switched to the promoted secret after replica promotion.

## Issues Encountered and Fixes Applied

### 1) Cross-Region RDS Encryption Error

Error observed:

- `InvalidParameterCombination: Cannot create a cross region unencrypted read replica from encrypted source`

Root cause:

- The source database was encrypted.
- For cross-region replicas, AWS requires explicit encryption in the destination region.
- KMS keys are region-scoped, so the replica must use a destination-region key.

Fix applied:

- Added `kms_key_id` support to the RDS module.
- Updated the replica path to use a destination-region KMS key ARN (`us-west-2`) via `aws_kms_alias.rds.target_key_arn`, with `kms_key_id` available as an override.

Outcome:

- Terraform successfully created the cross-region replica after the encryption settings were corrected.

### 2) Cross-Region Replica with Managed Master Password

Error observed:

- `InvalidParameterValue: Creating read replicas for source instance with engine mysql where ManageMasterUserPassword is enabled is not supported.`

Root cause:

- AWS MySQL read replicas do not support a source instance configured with `manage_master_user_password`.

Fix applied:

- Removed the managed-master-password path from the source instance.
- Switched to generated credentials using `random_password` and write-only password arguments (`password_wo`).
- Stored credentials in a dedicated Secrets Manager secret for app bootstrap.

Outcome:

- Primary instance became replica-compatible, and cross-region replication proceeded.

### 3) "Un-deletable" Infrastructure During Destroy

Error observed:

- `OperationNotPermitted` and `DependencyViolation` during `terraform destroy`.

Root cause:

- Production-grade deletion protection was enabled on ALBs and RDS.
- Protected resources could not be deleted, which blocked VPC teardown due to dependencies.

Fix applied:

- Manually disabled Deletion Protection in AWS Console for both regions (`us-east-1` and `us-west-2`):
  - ALB attributes
  - RDS instance settings

Outcome:

- Terraform destroy/apply workflows could proceed normally.

## Architectural Decisions Verified

During debugging and validation, the following design choices were confirmed:

- Host Header Validation: Apache responded correctly to the custom domain, not only AWS-generated DNS names.
- Immutable Infrastructure: Packer-baked AMIs were used, improving recovery speed and reducing bootstrap drift.
- Tagging Strategy: `local.common_tags` propagated across resources, supporting inventory, search, and governance at scale.

## Troubleshooting Checklist

If the replica fails to create, check these first:

- The source DB is not using `manage_master_user_password`.
- The replica is using a destination KMS key ARN.
- The source `replicate_source_db` value is the primary instance ARN.
- The secondary provider alias is targeting `us-west-2`.
- The primary and replica subnets are in the expected regions.

If Terraform says the saved plan is stale, regenerate the plan or run a fresh `terraform apply`.

## Related Files

- [`envs/prod/main.tf`](envs/prod/main.tf)
- [`envs/prod/provider.tf`](envs/prod/provider.tf)
- [`envs/prod/variables.tf`](envs/prod/variables.tf)
- [`envs/prod/outputs.tf`](envs/prod/outputs.tf)
- [`modules/rds/main.tf`](modules/rds/main.tf)
- [`modules/asg/main.tf`](modules/asg/main.tf)

## Summary

Day 27 is the first full multi-region environment in this repo. It shows how to compose reusable Terraform modules into a realistic failover-ready architecture while handling the details that usually break cross-region replication, especially database encryption and credential management.