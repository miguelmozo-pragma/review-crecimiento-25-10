# ElastiCache Redis module — review (pass 2)

The new module at `modules/elasticache/` provisions a cluster-mode-disabled Redis replication group with a private subnet group, a port-6379-restricted security group, a dedicated KMS CMK created only when no ARN is passed, and encryption at rest and in transit always on. The static implementation remains faithful to the plan on every point: file layout, provider block, naming, encryption posture, ingress restriction, single-node vs multi-node clamping via locals, the 40-char `replication_group_id` enforcement, and the output list (auth_token never exposed). Pass 1 raised one blocker — missing verification evidence — and that blocker is unchanged on this pass.

Watch for: the mandatory verification evidence is still missing (confirmed). The module files were last modified at 20:41 (unchanged since pass 1), and there is still no readable record of the coder's `terraform validate` run showing "Success! The configuration is valid." for variants A/B/C — no git repo, no report, no log, no leftover harness. The step instruction is explicit: if that evidence is missing, reject with a finding, and I am forbidden from re-running `terraform validate` myself to substitute for it.

**Verdict**: NEEDS_CHANGES

## High-level view

The static review is clean and identical to pass 1 — nothing in the five source files changed (same mtimes, same contents). All five files exist with the right structure. `providers.tf` declares `configuration_aliases = [aws.project]`, `version = ">= 5.0.0"`, and no backend. Every AWS resource sets `provider = aws.project`, every taggable resource merges `{ Name = ... }` with `var.additional_tags`, section separators are present, and all descriptions are in English.

Naming follows the convention exactly: `base_name = "cb-${var.environment}"`, the `elasticache` component literal lives in `locals.tf` (not passed as a variable), the security group uses the `sg` component literal, and the KMS key/alias use the `kms` literal. The `replication_group_id` is forced lowercase in locals and the composed length is enforced in `variables.tf` against the longest (`prod`) prefix, so the AWS 40-char limit holds for every environment, both enforced and documented.

Security posture is correct for every item on the list: `at_rest_encryption_enabled = true` with a CMK, `transit_encryption_enabled = true`, ingress only from `allowed_security_group_ids`/`allowed_cidr_blocks` on 6379 (via dynamic blocks so empty lists open nothing), no `0.0.0.0/0` ingress, `enable_key_rotation = true` on the dedicated key (CKV_AWS_7 never skipped), `auth_token` marked `sensitive` and absent from outputs, and the one checkov skip (egress-all) carries a Spanish justification. Both validation scenarios are supported without cross-variable validation conflicts because coherence is handled in locals.

The single blocker from pass 1 is unaddressed. The module cannot be approved because the required proof that it actually validates is not recorded anywhere readable, and the step forbids me from producing that proof myself. The source did not change between passes, so there is no new static concern to raise.

<details>
<summary>Issues (1)</summary>

1. **Missing verification evidence (blocker, carried over from pass 1, unaddressed)** — The step mandates the reviewer confirm the coder recorded `terraform validate` → "Success! The configuration is valid." for variants A/B/C. No git commit, report, log, or harness output exists to read, and the module files are unchanged since pass 1. Re-run the mandated harness (variants A/B/C) and record the exact "Success!" output where the reviewer can read it (commit message, a notes/log file in `.agents/tasks/`, or the step's recorded command output); delete the harness afterward.

</details>

<details>
<summary>Details</summary>

### File structure and providers

All five files are present (`main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `providers.tf`) and non-empty. `providers.tf` declares exactly what the convention requires:

```hcl
terraform {
  required_providers {
    aws = {
      configuration_aliases = [aws.project]
      source                = "hashicorp/aws"
      version               = ">= 5.0.0"
    }
  }
}
```

No backend, no kubernetes/helm aliases (correct — this module creates no k8s resources). Every AWS resource in `main.tf` (`aws_kms_key`, `aws_kms_alias`, `aws_elasticache_subnet_group`, `aws_security_group`, `aws_elasticache_replication_group`) and the `aws_caller_identity` data source sets `provider = aws.project`. Section separators and English descriptions are present throughout.

### Naming and the 40-char replication_group_id enforcement

`locals.tf` sets `base_name = "cb-${var.environment}"` and builds every name with the `elasticache` literal inline; the SG uses the `sg` literal (`cb-{env}-sg-elasticache-{name}`) and KMS uses the `kms` literal. `replication_group_id = lower("${local.base_name}-elasticache-${var.name}")` keeps the id lowercase.

The 40-char limit is enforced on the input in `variables.tf`:

```hcl
validation {
  condition     = length("cb-prod-elasticache-${var.name}") <= 40
  error_message = "name too long: composed replication_group_id 'cb-{env}-elasticache-{name}' must be <= 40 chars (prod has the longest prefix)."
}
```

Checking against `prod` (the longest prefix) guarantees every environment stays within 40 chars. A second validation enforces `^[a-z][a-z0-9-]*$`. The constraint is both enforced and documented in the variable description and locals comments — matching the plan's final unambiguous rule.

### Encryption and KMS

`at_rest_encryption_enabled = true` with `kms_key_id = local.kms_key_arn`, and `transit_encryption_enabled = true`. The dedicated CMK is created only when `var.kms_key_arn == null` (`count = local.create_kms ? 1 : 0`), has `enable_key_rotation = true` (CKV_AWS_7 never skipped), a 30-day deletion window, and the root-account `kms:*` policy from `security.md`. `local.kms_key_arn` centralizes the effective ARN and is used by both the replication group and the `kms_key_arn` output.

### Access control and no public access

The security group opens 6379 only via two dynamic ingress blocks — one per entry in `allowed_security_group_ids` and a single block for `allowed_cidr_blocks` (gated on `length(...) > 0`). With both lists empty (the defaults), no ingress rule is created, so there is no path to public access. Egress is all-open with a Spanish-justified `checkov:skip=CKV_AWS_382`. Private placement is delegated to the caller via the subnet group.

### auth_token handling

`auth_token` is `sensitive = true`, defaults to `null`, and is passed straight to the resource — null means unconfigured. The validation allows null or a 16–128 char value, and it never appears in `outputs.tf`.

### Both validation scenarios

Cross-field coherence is handled in locals, not in `validation` blocks (Terraform forbids cross-variable references in validations anyway):

```hcl
effective_failover = var.num_cache_clusters > 1 ? var.automatic_failover_enabled : false
effective_multi_az = local.effective_failover ? var.multi_az_enabled : false
```

- Scenario (a) `num_cache_clusters=2`, failover/multi-az `true`, kms null → dedicated CMK branch active, failover and multi-az pass through as true.
- Scenario (b) `num_cache_clusters=1`, failover/multi-az `false`, kms passed → failover clamps to false, multi-az clamps to false, dedicated-CMK branch skipped. No AWS-side conflict even if a caller left the `true` defaults in place with a single node.

Each variable's own `validation` references only itself, so neither scenario trips a validation error.

### Outputs

Exactly the required list, each with a description: `replication_group_id`, `replication_group_arn`, `primary_endpoint_address`, `reader_endpoint_address`, `port` (literal 6379), `security_group_id`, `kms_key_arn` (effective CMK). No `auth_token` output.

### Scope

Only `modules/elasticache/` was created (five files, mtimes 20:40–20:41, unchanged since pass 1). No new or modified layer/tfvars/other-module files are attributable to this change. Scope is respected.

### Verification gate (blocker, unaddressed)

The step requires reading the coder's recorded `terraform validate` output — "Success! The configuration is valid." — for variants A (defaults/2-node/dedicated-KMS), B (single-node/passed-KMS), and C (auth + explicit size). On this pass I re-checked:
- No git repository exists (`git status` reports "not a git repository"), so there is no commit message carrying the output.
- No report, notes, or log file in `.agents/tasks/` records the run — only `elasticache-plan.md` and the pass-1 review artifacts exist. The only files containing the string "Success! The configuration is valid." are the review documents themselves (quoting the expected output) and the unrelated `microservice-*` artifacts.
- The harness dir `/tmp/ec-validate/` does not exist.
- The module source files are unchanged since pass 1 (mtimes 20:40–20:41), so no re-validation was performed after the first review flagged this.

With no readable evidence of a successful validate, and an explicit instruction not to re-run `terraform validate`/`fmt`/`init` to substitute for it, the verification gate is unsatisfied. There is no specific articulable doubt about the code that the single permitted spot-check could resolve — the gap is the absence of recorded evidence, not a code question — so the spot-check is not used. The static review is otherwise clean, but the gate is a hard requirement, so the verdict is NEEDS_CHANGES.

</details>

<details>
<summary>File map</summary>

- `modules/elasticache/providers.tf` — terraform block, `aws` required provider with `configuration_aliases = [aws.project]`, `>= 5.0.0`, no backend.
- `modules/elasticache/variables.tf` — all inputs grouped by separators; `name` carries the regex + 40-char-composed validations; `auth_token` sensitive with 16–128 validation.
- `modules/elasticache/locals.tf` — naming (`elasticache`/`sg`/`kms` literals), lowercase id, create-or-use KMS branch, failover/multi-az clamping.
- `modules/elasticache/main.tf` — caller identity, dedicated CMK + alias (count-gated), subnet group, SG (dynamic 6379 ingress + justified egress skip), replication group (encryption on, clamped failover/multi-az).
- `modules/elasticache/outputs.tf` — seven outputs, no auth_token.

Full diff: no VCS in the workspace; review based on current file contents.

</details>
