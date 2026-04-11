# Day 23 Learning Journal — Exam Preparation

---

## Domain Audit

Honest self-assessment against the official Terraform Associate exam domains.
**Green** = can explain it and have done it hands-on.
**Yellow** = understand conceptually but limited hands-on.
**Red** = not confident — needs focused study time.

### Domain 1: Understand Infrastructure as Code Concepts (16%)

| Topic | Rating | Notes |
|-------|--------|-------|
| IaC and its benefits | 🟢 Green | Can articulate idempotency, drift detection, version control, reproducibility |
| IaC vs configuration management | 🟢 Green | Terraform vs Ansible vs Chef — different layers, different jobs |
| Declarative vs procedural | 🟢 Green | Terraform is declarative; Ansible can be either |
| Immutable vs mutable infrastructure | 🟢 Green | Built on this for 22 days — replace vs patch |
| IaC advantages over manual provisioning | 🟢 Green | Speed, consistency, auditability, testability |

### Domain 2: Understand Terraform's Purpose (20%)

| Topic | Rating | Notes |
|-------|--------|-------|
| Terraform's multi-cloud value | 🟢 Green | Same workflow regardless of provider |
| Provider-based architecture | 🟢 Green | Used AWS, random, local, tls, null providers |
| Terraform vs competitors (Pulumi, CloudFormation, CDK) | 🟡 Yellow | Know Terraform's positioning but not deep on others |
| Terraform state purpose | 🟢 Green | Source of truth, drift detection, dependency graph |
| Benefits of state | 🟢 Green | Performance (cached data), metadata, parallelism |

### Domain 3: Understand Terraform Basics (24%)

| Topic | Rating | Notes |
|-------|--------|-------|
| Providers and version constraints | 🟢 Green | Used `~>`, `>=`, `=`, `!=` constraints extensively |
| Provider aliases | 🟡 Yellow | Know the syntax but only used in multi-region work |
| Installing providers (`terraform init`) | 🟢 Green | Lock file (`.terraform.lock.hcl`) behaviour understood |
| Provider lock file purpose | 🟡 Yellow | Know it locks provider versions but need to review `-upgrade` flag |
| Resource configuration | 🟢 Green | 22 days of writing resource blocks |
| Variable types and validation | 🟢 Green | string, number, bool, list, map, object, any — plus validation blocks |
| Output values | 🟢 Green | Including sensitive outputs and their state behaviour |
| Local values | 🟢 Green | `locals {}` block, expressions, when to prefer over variables |
| Data sources | 🟢 Green | AMI lookup, VPC data, subnet data — all used extensively |
| Built-in functions | 🟡 Yellow | Know the common ones; `templatefile`, `file`, `jsondecode`, `merge`, `flatten` — less confident on `cidrsubnet`, `formatlist`, `setproduct` |
| Module basics | 🟢 Green | Source, version, inputs, outputs, child module calling |
| Non-cloud providers | 🟡 Yellow | Used `random` briefly; `local`, `tls`, `null` need review |

### Domain 4: Use the Terraform CLI (26%) — Highest weighted domain

| Topic | Rating | Notes |
|-------|--------|-------|
| `terraform init` flags and behaviour | 🟡 Yellow | Know common flags; need to review `-upgrade`, `-migrate-state`, `-reconfigure` |
| `terraform plan` output interpretation | 🟢 Green | +/-/~ symbols, counts, forced replacement detection |
| `terraform apply` flags | 🟢 Green | `-auto-approve`, `-target`, `-var`, `-var-file`, `-out` |
| `terraform destroy` | 🟢 Green | Including `-target` for partial destruction |
| `terraform fmt` | 🟢 Green | Canonical style, `-check`, `-recursive`, `-diff` |
| `terraform validate` | 🟢 Green | What it does vs does not check |
| `terraform state` subcommands | 🟡 Yellow | Used `list` and `show`; `mv` and `rm` need hands-on |
| `terraform import` | 🟡 Yellow | Know the concept; need to practice the workflow |
| `terraform taint` / `terraform untaint` | 🟡 Yellow | Deprecated but still appears on exam — know that `-replace` is the modern equivalent |
| `terraform workspace` | 🟢 Green | `new`, `select`, `list`, `delete` — used throughout challenge |
| `terraform output` | 🟡 Yellow | `-json`, `-raw` flags need review |
| `terraform graph` | 🔴 Red | Know it outputs DOT format but have never used it |
| `terraform providers` | 🔴 Red | Have not used it; need to understand output format |
| `terraform login` / `terraform logout` | 🟡 Yellow | Know what it does (Terraform Cloud auth) but have only done it via CLI config token |
| `terraform autocomplete` | 🔴 Red | Never configured it — need to know install/uninstall commands |

### Domain 5: Interact with Terraform Modules (12%)

| Topic | Rating | Notes |
|-------|--------|-------|
| Module sources | 🟢 Green | Local, registry, GitHub, S3, GCS |
| Module versioning | 🟢 Green | `version = "~> 3.0"` with registry modules |
| Module inputs/outputs | 🟢 Green | Variables as module inputs, outputs.tf in child modules |
| Root module vs child module | 🟢 Green | Clear mental model |
| `providers` argument in modules | 🟡 Yellow | Passing provider aliases to modules — need review |
| Published vs private registry | 🟡 Yellow | Know Terraform Registry; private registry in Terraform Cloud less familiar |
| Module meta-arguments | 🟡 Yellow | `count`, `for_each`, `depends_on`, `providers` in module blocks |

### Domain 6: Navigate the Core Terraform Workflow (8%)

| Topic | Rating | Notes |
|-------|--------|-------|
| Write → Plan → Apply cycle | 🟢 Green | 22 days of this |
| Saved plan files | 🟢 Green | `-out` flag, applying from plan file |
| When to use `-target` | 🟡 Yellow | Know it exists; less clear on when it is appropriate vs risky |
| Refresh-only runs | 🟡 Yellow | `terraform apply -refresh-only` — concept understood but not used |

### Domain 7: Implement and Maintain State (8%)

| Topic | Rating | Notes |
|-------|--------|-------|
| Remote state backends | 🟢 Green | S3 + DynamoDB, Terraform Cloud — used both |
| State locking | 🟢 Green | DynamoDB locking, what happens on lock failure |
| `terraform_remote_state` data source | 🟡 Yellow | Know the concept and syntax; used in multi-module setup |
| State file structure | 🟡 Yellow | Know it's JSON with serial/version/resources — need to read an actual file carefully |
| Sensitive values in state | 🟢 Green | Everything goes into state — encryption is non-optional |
| State migration (`-migrate-state`) | 🔴 Red | Never done a backend migration hands-on |
| Partial backend config | 🔴 Red | `-backend-config` flag for separating backend credentials from code |

### Domain 8: Read, Generate, and Modify Configuration (8%)

| Topic | Rating | Notes |
|-------|--------|-------|
| HCL syntax | 🟢 Green | Blocks, arguments, expressions, references |
| `count` and `for_each` | 🟢 Green | Including `count.index`, `each.key`, `each.value` |
| `dynamic` blocks | 🟢 Green | Used in ASG tags and security group rules |
| `for` expressions | 🟡 Yellow | List and map transforms — know syntax but write slowly |
| Conditional expressions | 🟢 Green | `condition ? true_val : false_val` |
| `depends_on` meta-argument | 🟢 Green | When implicit dependencies are not detected |
| `lifecycle` meta-arguments | 🟢 Green | `create_before_destroy`, `prevent_destroy`, `ignore_changes` |
| `provisioner` blocks | 🟡 Yellow | `local-exec`, `remote-exec` — know the syntax and risks |
| `templatefile()` function | 🟢 Green | Used in user_data.sh rendering |

### Domain 9: Understand Terraform Cloud Capabilities (4%)

| Topic | Rating | Notes |
|-------|--------|-------|
| Remote runs vs local runs | 🟡 Yellow | Know the concept; need to review execution modes |
| Terraform Cloud workspaces vs OSS workspaces | 🟡 Yellow | Different concepts — TFC workspaces are more like separate projects |
| Sentinel and when it runs | 🟢 Green | Between plan and apply — implemented in Days 21-22 |
| Variable types in TFC | 🟡 Yellow | Terraform variables vs environment variables, sensitive flag |
| Private module registry | 🟡 Yellow | How versioning works in TFC private registry |
| Cost estimation limitations | 🟢 Green | Covered in Day 22 lab |

---

## Domain Summary (honest totals)

| Color | Count | % of topics |
|-------|-------|-------------|
| 🟢 Green | 41 | 65% |
| 🟡 Yellow | 21 | 33% |
| 🔴 Red | 4 | 6% |

**Priority focus areas:**
1. 🔴 `terraform graph`, `terraform providers`, `terraform autocomplete`, backend migration
2. 🟡 CLI flags (`init -upgrade`, `output -json`, `taint` vs `-replace`)
3. 🟡 `terraform state mv` and `rm` hands-on
4. 🟡 Non-cloud providers (`local`, `tls`, `null`)
5. 🟡 Provider aliases in modules (the `providers` argument)

---

## Study Plan — Days 24 Through Exam

Target exam date: Day 30 (7 days from today).

| Day | Topic | Current Confidence | Study Method | Time |
|-----|-------|-------------------|--------------|------|
| 24 | `terraform state mv`, `rm`, `import` | 🟡 Yellow | Run each against test infra; write 3 scenario questions | 60 min |
| 24 | `terraform graph` and `terraform providers` | 🔴 Red | Run against day22 infra; read docs for output format | 30 min |
| 24 | `terraform autocomplete` | 🔴 Red | Install, use, understand `terraform -install-autocomplete` | 15 min |
| 25 | Backend migration (`-migrate-state`, `-reconfigure`) | 🔴 Red | Create local backend → migrate to S3; document steps | 45 min |
| 25 | Partial backend config (`-backend-config` flag) | 🔴 Red | Implement for day22 infra; understand separation of credentials from code | 30 min |
| 25 | `terraform init` all flags | 🟡 Yellow | Read docs; write one question per flag | 30 min |
| 26 | Non-cloud providers deep dive | 🟡 Yellow | Build `local + tls + null` example; write 3 practice questions | 45 min |
| 26 | Provider aliases in modules | 🟡 Yellow | Pass aliased provider to child module; verify outputs | 30 min |
| 26 | `terraform_remote_state` data source | 🟡 Yellow | Connect two root modules via remote state; write scenario question | 30 min |
| 27 | `for` expressions and `setproduct`, `flatten`, `cidrsubnet` | 🟡 Yellow | Write examples; 5 flashcards | 45 min |
| 27 | Provisioner blocks (`local-exec`, `remote-exec`) | 🟡 Yellow | Read docs; understand when they run vs when they are risky | 20 min |
| 27 | `terraform apply -refresh-only` | 🟡 Yellow | Run against real infra; document what it does | 20 min |
| 28 | Full official practice question set — timed pass | Mixed | 20 official questions under exam conditions | 40 min |
| 28 | Review every wrong answer — add to flashcard deck | Mixed | For each wrong answer: explain why it was wrong, why correct is right | 30 min |
| 28 | Terraform Cloud: execution modes, workspace types | 🟡 Yellow | Read TFC docs on remote vs local vs agent execution | 30 min |
| 29 | CLI command speed run — all 15 commands, one sentence each | Mixed | Write the CLI self-test from memory, then check | 20 min |
| 29 | State file structure deep read | 🟡 Yellow | Open a real `terraform.tfstate` JSON, identify every field | 20 min |
| 29 | Write 5 more practice questions from weak areas | Mixed | Focus on state, CLI flags, non-cloud providers | 30 min |
| 30 (exam day) | Light review only | — | Re-read CLI self-test notes, flashcards — no new material | 30 min |

---

## CLI Commands Self-Test

*Written from memory — no docs copy-paste.*

### `terraform init`
**What it does:** Downloads the providers defined in `required_providers`, sets up the backend (creates the remote state connection), and installs any module dependencies. Also creates or updates the `.terraform.lock.hcl` provider lock file.
**When I'd use it:** Every time I clone a repository or add a new provider to `required_providers`. Also after changing the backend configuration.

---

### `terraform validate`
**What it does:** Checks the configuration for syntax errors and internal consistency — undefined variables, references to resources that don't exist, wrong argument types. Does NOT require provider credentials and does NOT contact AWS. It only looks at the HCL configuration files.
**When I'd use it:** In CI as the first fast gate — before `terraform plan` — because it is cheap (no AWS calls) and catches a wide class of errors.

---

### `terraform fmt`
**What it does:** Rewrites `.tf` files to the canonical Terraform style — consistent indentation, alignment of `=` signs in blocks, newlines between resource blocks. With `-check` it exits non-zero if any file needs formatting without modifying files.
**When I'd use it:** In CI with `-check -recursive` to enforce style. Locally before every commit.

---

### `terraform plan`
**What it does:** Compares the desired state (`.tf` files) against the current state (state file) and generates a diff showing what will be created, changed, or destroyed. With `-out=file.tfplan` it saves the plan as a binary artifact that can be applied deterministically.
**When I'd use it:** Before every `terraform apply`, without exception. When reviewing a PR, running plan against the PR branch is the infrastructure equivalent of reviewing a code diff.

---

### `terraform apply`
**What it does:** Executes the changes described in a plan — creates, updates, or destroys real infrastructure and then updates the state file to reflect the new reality. When given a saved plan file (`terraform apply plan.tfplan`), it applies exactly that plan without re-planning.
**When I'd use it:** After reviewing the plan and confirming it is correct. Always from a saved plan file in production.

---

### `terraform destroy`
**What it does:** Destroys all infrastructure managed by the current configuration in the current workspace. Effectively runs `terraform apply` with every resource marked for destruction. Accepts `-target` to destroy individual resources.
**When I'd use it:** Tearing down dev environments, cleaning up after testing, removing ephemeral PR preview environments.

---

### `terraform output`
**What it does:** Reads output values from the state file and prints them to stdout. With `-json` it returns a JSON object of all outputs. With `-raw` it returns the raw string value of a single output without quoting (useful for piping into scripts).
**When I'd use it:** Retrieving the ALB DNS name or ASG name after an apply, or in CI/CD scripts that need to consume Terraform outputs for downstream steps (e.g. passing the kubeconfig to a Helm step).

---

### `terraform state list`
**What it does:** Lists all resources currently tracked in the state file, one per line, using their full Terraform address (e.g. `aws_autoscaling_group.webserver`, `module.cluster.aws_lb.main`).
**When I'd use it:** Before running `terraform state mv` or `terraform state rm`, to confirm the exact resource address. Also useful for auditing what Terraform currently manages.

---

### `terraform state show`
**What it does:** Displays the full recorded attributes of a specific resource in the state file — every attribute that Terraform knows about it, formatted like a resource block.
**When I'd use it:** When debugging unexpected plan output (e.g. "why does Terraform want to change this attribute?"). Comparing what Terraform thinks the resource looks like against what it actually looks like in AWS.

---

### `terraform state mv`
**What it does:** Moves a resource from one address to another within the state file, or between two state files. Does NOT touch real infrastructure — it only renames the state record. After moving, running `terraform plan` should show no changes.
**When I'd use it:** Refactoring a configuration — for example, if I rename a resource block from `aws_s3_bucket.logs` to `aws_s3_bucket.alb_logs` in code, I run `terraform state mv aws_s3_bucket.logs aws_s3_bucket.alb_logs` so Terraform does not destroy and re-create the real bucket.

---

### `terraform state rm`
**What it does:** Removes a resource's record from the state file. Does NOT destroy the real infrastructure. After `state rm`, Terraform no longer manages that resource — a subsequent `plan` will show it as a new resource to create (because it no longer appears in state).
**When I'd use it:** When I want to stop managing a resource with Terraform without destroying it. For example, handing off an S3 bucket to a different team's Terraform configuration — I `state rm` it from my state, they `import` it into theirs.

---

### `terraform import`
**What it does:** Brings an existing real-world resource (created manually or by another system) under Terraform management by writing its current state into the state file. Requires writing the matching resource configuration in `.tf` files first — the import only handles state, not configuration generation.
**When I'd use it:** Adopting IaC for existing manually-created infrastructure. The workflow: write the Terraform resource block, run `terraform import <address> <real-resource-id>`, run `terraform plan` to verify it shows no changes.

---

### `terraform taint` (deprecated — know for exam)
**What it does:** Marks a resource in the state file as "tainted," which causes it to be destroyed and recreated on the next `terraform apply`. The resource is not immediately affected — it is just flagged.
**Modern equivalent:** `terraform apply -replace=<resource_address>` is the current way to force recreation. `terraform taint` was deprecated in Terraform 0.15.2 but still appears on the Associate exam.
**When I'd use it:** Forcing recreation of an EC2 instance whose user data failed to apply correctly, or recreating a resource that is in an unknown/broken state.

---

### `terraform workspace`
**What it does:** Manages named workspaces — separate state files within the same backend. `workspace new <name>` creates a new workspace, `workspace select <name>` switches to it, `workspace list` shows all workspaces, `workspace delete <name>` removes an empty one. Inside configuration, `terraform.workspace` returns the current workspace name.
**When I'd use it:** Environment isolation (dev/staging/prod) within a single backend. Throughout this challenge to separate dev and prod state files.

---

### `terraform providers`
**What it does:** Reads the configuration and prints the tree of providers required — the provider type, source address, and version constraints for the current configuration and all child modules.
**When I'd use it:** Auditing which providers a configuration depends on before running `terraform init`, or diagnosing why a particular provider version is being resolved.

---

### `terraform login`
**What it does:** Opens a browser to the Terraform Cloud login page and saves the resulting API token to the Terraform CLI credentials file (`~/.terraform.d/credentials.tfrc.json`). After login, `terraform init` can configure a Terraform Cloud backend without storing credentials in code.
**When I'd use it:** Setting up a new developer machine to work with Terraform Cloud workspaces. In CI, I use the `TF_TOKEN_app_terraform_io` environment variable instead.

---

### `terraform graph`
**What it does:** Outputs the Terraform dependency graph in DOT format, which can be rendered to a visual graph using Graphviz (`terraform graph | dot -Tsvg > graph.svg`). Shows the relationships between resources, providers, and data sources.
**When I'd use it:** Debugging a complex dependency graph where `terraform apply` seems to be applying resources in an unexpected order, or where a circular dependency error is difficult to trace.

---

## Non-Cloud Provider Code Example

```hcl
# Practical real-world combination: random + tls + local
# Use case: bootstrap SSH keys and write them to disk after infrastructure creation

terraform {
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    tls    = { source = "hashicorp/tls",    version = "~> 4.0" }
    local  = { source = "hashicorp/local",  version = "~> 2.5" }
  }
}

# Generate a unique name suffix to avoid collisions
resource "random_id" "suffix" {
  byte_length = 4
}

# Generate a DB password — stored in state, never in code
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Generate an SSH key pair for EC2 access
resource "tls_private_key" "bastion" {
  algorithm = "ED25519"
}

# Write the public key to disk for use by Ansible
resource "local_file" "bastion_pub" {
  content         = tls_private_key.bastion.public_key_openssh
  filename        = "${path.module}/keys/bastion.pub"
  file_permission = "0644"
}

# Write the private key — sensitive file, mode 0600
resource "local_sensitive_file" "bastion_priv" {
  content         = tls_private_key.bastion.private_key_pem
  filename        = "${path.module}/keys/bastion.pem"
  file_permission = "0600"
}

output "cluster_suffix" {
  value = random_id.suffix.hex
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true  # Not printed in terminal; stored in state
}
```

**Where these providers are useful in real Terraform configurations:**

`random` is essential for anything requiring globally unique names. AWS S3 bucket names must be globally unique across all AWS accounts. `random_id` appended to a bucket name makes it unique without hardcoding a specific suffix in code. `random_password` generates database credentials that do not exist in version control — they are generated at `terraform apply` time and stored in state (which must be encrypted).

`tls` is useful for bootstrapping environments where certificate infrastructure does not yet exist. In the homelab, I used it to generate self-signed certificates for Vault before a proper CA was in place. The key point for the exam: both private keys and certificates generated by `tls_private_key` are stored in state in plaintext — state encryption is not optional when using this provider.

`local` is valuable for closing the gap between Terraform (which creates infrastructure) and configuration management tools (which configure the things Terraform creates). Terraform creates an EC2 instance, writes the IP and SSH public key to a `local_file` as an Ansible inventory, and Ansible picks it up from disk. This pattern avoids complex API chaining between tools.

`null` (`null_resource`) is useful for running commands (via `local-exec` provisioners) when a dependency changes, without tying that action to a real infrastructure resource. The `triggers` argument controls when the `null_resource` is recreated — and therefore when its provisioners run.

---

## Practice Questions — Five Original

### Q1: State Behaviour After Manual Resource Deletion

You have a `terraform.tfstate` that includes an `aws_s3_bucket.logs` resource.
A teammate manually deletes that S3 bucket through the AWS Console without modifying the state file.
You then run `terraform plan` with no other changes to the configuration.
What does Terraform show?

A) No changes — Terraform does not detect out-of-band deletions
B) The bucket will be shown as a resource to be created (plan shows +1 resource)
C) Terraform immediately destroys all remaining infrastructure to maintain consistency
D) An error that the state file is corrupted

**Answer: B**

**Explanation:**
`terraform plan` refreshes state by querying the real infrastructure before comparing against the desired configuration. When it queries for `aws_s3_bucket.logs` and finds it does not exist, it compares that (nothing) against the desired state (bucket should exist) and generates a plan to create it. This is drift detection — one of the core reasons state exists. A is wrong because Terraform does refresh real state on each plan. C is wrong because Terraform only manages what it is told to manage — it does not have a "nuke everything" mode on drift. D is wrong because an out-of-band deletion does not corrupt state; state just becomes stale until the next refresh.

---

### Q2: `terraform state rm` Behaviour

You run `terraform state rm aws_iam_role.legacy_role`. What is the outcome?

A) The IAM role is immediately deleted from AWS
B) The IAM role is marked as tainted and will be destroyed on the next apply
C) The IAM role's record is removed from the Terraform state file; the real IAM role continues to exist in AWS
D) The command fails because you must use `terraform destroy -target` to remove resources

**Answer: C**

**Explanation:**
`terraform state rm` only modifies the Terraform state file — it removes the record of the resource. It does not touch AWS. After running it, the IAM role continues to exist in AWS; Terraform simply no longer knows about it. A subsequent `terraform plan` will show the role as a new resource to create (if it is still in the `.tf` files) or will show nothing (if the resource block has also been removed from the configuration). A is wrong because state commands never call AWS APIs to modify real infrastructure. B is wrong — taint is a different concept. D is wrong — `terraform state rm` is exactly the right command for removing state records without destroying.

---

### Q3: Provider Alias Module Inheritance

You have two `aws` providers configured — one default (us-east-1) and one aliased (`aws.west`, us-west-2). You call a child module and do NOT pass a `providers` argument. Which provider does the child module use?

A) It always errors — provider aliases cannot be used in modules without explicit passing
B) The child module uses the default (non-aliased) AWS provider
C) The child module uses all configured providers automatically
D) The child module uses the provider that matches the region of the first resource it encounters

**Answer: B**

**Explanation:**
When a child module does not receive an explicit `providers` argument, it inherits only the default provider configuration (the one without an `alias`). Provider aliases are NOT inherited automatically — they must be explicitly passed via the `providers` map in the module block:
```hcl
module "west_resources" {
  source = "./modules/bucket"
  providers = {
    aws = aws.west
  }
}
```
A is wrong — modules work fine without passing providers; they just use the default. C is wrong — aliases are explicitly opt-in. D is wrong — Terraform has no such inference mechanism.

---

### Q4: sensitive = true Output Behaviour

You declare an output with `sensitive = true`. Which statement about this output is correct?

A) The value is encrypted in the state file using AES-256
B) The value is omitted from the state file entirely for security
C) The value is masked as `(sensitive value)` in terminal output but IS stored as plaintext in the state file
D) The `sensitive = true` flag prevents the value from being used by other Terraform configurations

**Answer: C**

**Explanation:**
`sensitive = true` on an output does two things: it masks the value in terminal output (`terraform output` shows `(sensitive value)`) and it prevents the value from appearing in plan output. However, it does NOT encrypt the state file — sensitive values are stored as plaintext in `terraform.tfstate`. This is why state files must be stored in encrypted backends (S3 with SSE, Terraform Cloud which encrypts at rest). A is wrong — Terraform has no built-in value-level encryption. B is wrong — the value IS in state, just not displayed in the terminal. D is wrong — sensitive outputs can absolutely be consumed by `terraform_remote_state` data sources in other configurations.

---

### Q5: When to Use `depends_on` on a Module

You have a `module.vpc` that creates a VPC and subnets, and a `module.eks` that creates an EKS cluster in those subnets. The EKS module references the subnet IDs via `module.vpc.subnet_ids`. Do you need an explicit `depends_on = [module.vpc]` on the EKS module?

A) Yes — modules always require explicit `depends_on` for ordering
B) No — because the EKS module references `module.vpc.subnet_ids`, Terraform automatically infers the dependency
C) Yes — `depends_on` is required whenever one module calls another module
D) No — Terraform always creates modules in alphabetical order by name

**Answer: B**

**Explanation:**
Terraform builds an implicit dependency graph from resource and value references. Because `module.eks` uses `module.vpc.subnet_ids` as an input, Terraform knows the VPC module must complete before the EKS module can begin — it infers this from the data flow. Explicit `depends_on` on modules is only needed when a module depends on another module's effects but does NOT reference any of its output values (i.e., there is a hidden dependency that Terraform cannot see from the code). A is wrong — explicit depends_on is rarely needed with good module design. C is wrong for the same reason. D is wrong — Terraform uses the dependency graph, not alphabetical order.

---

## Official Practice Question Results

**Attempted:** All official HashiCorp sample questions (20 questions)
**First-attempt score:** 17/20 (85%)

**Missed questions and learnings:**

**Missed Q1: Terraform Cloud workspace execution modes**
I confused "remote execution" (plan and apply run on Terraform Cloud's workers) with "local execution" (plan and apply run locally, but state is stored remotely). The exam distinguished between these clearly. Learning: in remote execution mode, local environment variables do NOT automatically pass to the run — they must be configured as workspace variables in Terraform Cloud.

**Missed Q2: `terraform init -upgrade` vs `-reconfigure`**
I knew `-upgrade` ignores the lock file and fetches the latest allowed provider versions. I confused `-reconfigure` (ignores existing backend configuration, does not attempt to migrate state) with `-migrate-state` (migrates state when changing backends). Learning: `-reconfigure` is for when you want to reinitialise with a new backend without migrating the existing state. `-migrate-state` is for when you want to move state to the new backend.

**Missed Q3: When `terraform apply` is run without a plan file and detects a conflict**
The question asked what happens if `terraform apply` is run without a saved plan file and the infrastructure has changed since the implicit plan was generated. I incorrectly answered that it applies anyway. The correct answer is that Terraform re-generates the plan at apply time and applies that — it does not check for drift between plan time and apply time when running without a saved plan file. This reinforced exactly why plan file pinning is the correct practice — without it, you can apply a different plan than the one reviewed.

**Added to study plan:** Terraform Cloud execution modes (Day 28 session), `terraform init` flag deep dive (Day 25 session).

---

## Blog Post

**URL:** https://medium.com/@anthonyzottor/day-23-preparing-for-the-terraform-associate-exam

**Summary:** Walks through the self-audit approach (green/yellow/red against all domains), identifies the CLI commands domain as the most dangerous underestimate (highest weight at 26%, deepest on flags and state subcommands), shares the structured study plan for Days 24-30, explains what the official practice question misses taught about execution modes and backend init flags, and provides the non-cloud provider examples with real-world use cases.

---

## Social Media

**URL:** https://www.linkedin.com/posts/anthonyzottor/day-23-terraform-exam-prep

**Post text:**
🎯 Day 23 of the 30-Day Terraform Challenge — full exam prep mode.

Audited every objective domain against the official exam guide:
✅ 65% Green (can explain and have done hands-on)
🟡 33% Yellow (conceptual but limited hands-on — study time here)
🔴 6% Red (terraform graph, autocomplete, backend migration — focused sessions needed)

The insight that surprised me: the CLI commands domain is 26% of the exam — the highest single weight. And it goes deep. Not just "what does terraform plan do" but "what is the difference between terraform init -reconfigure and -migrate-state" and "what does terraform state rm do to real infrastructure."

Answer to that last one: nothing. `terraform state rm` removes the state record only — the real resource keeps running. But the subsequent `terraform plan` will show it as a new resource to create, because Terraform no longer knows it exists.

Structured study plan in place for Days 24-30. Exam day is Day 30.

#30DayTerraformChallenge #TerraformChallenge #Terraform #TerraformAssociate #CertificationPrep #AWSUserGroupKenya #EveOps