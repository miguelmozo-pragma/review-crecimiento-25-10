# Implementation Plan — `modules/elasticache` (ElastiCache Redis)

Scope: ONLY create the reusable module at
`/home/miguel-mozo/Documents/Review de crecimiento/Terraform iac/Core bancario migrado/modules/elasticache/`.
Do NOT create or modify any layer, tfvars, or other module. `<ROOT>` below means the
workspace root `/home/miguel-mozo/Documents/Review de crecimiento/Terraform iac/Core bancario migrado`.

## Design decisions (grounded in steering + existing modules)

- **File structure**: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `providers.tf`
  (per `create-module.md`). All resources on one `main.tf` — the module is small; no need
  to split like `microservice` does. KMS, subnet group, SG, and replication group all live
  in `main.tf` with section separators.
- **Provider**: `configuration_aliases = [aws.project]`, `version = ">= 5.0.0"`, no backend
  (mirrors `modules/microservice/providers.tf`). Only the AWS provider is required (no k8s/helm).
- **Naming**: `base_name = "cb-${var.environment}"`, component literal `elasticache`; SG uses
  component literal `sg`; KMS uses component literal `kms` (matches `security.md` table example
  `cb-dev-kms-elasticache`). Alias is `alias/cb-{env}-kms-elasticache-{name}`.
- **Cluster mode**: cluster-mode-disabled replication group driven by `num_cache_clusters`
  (1 primary + N-1 replicas). This satisfies both validation scenarios without node-group config.
- **KMS**: create a dedicated CMK only when `var.kms_key_arn == null` (security.md: each service
  gets its own CMK; rotation always on — `CKV_AWS_7` is never skipped). When an ARN is passed,
  reuse it. The effective ARN is centralized in `local.kms_key_arn`.
- **Encryption**: `at_rest_encryption_enabled = true` + CMK, `transit_encryption_enabled = true`
  (security.md: TLS obligatorio, cifrado en reposo con CMK dedicada).
- **No public access**: no SG ingress from `0.0.0.0/0` by default; ingress only from
  `allowed_security_group_ids` / `allowed_cidr_blocks`. Private subnets via the subnet group.
- **Parameter group**: OMITTED. Redis 7.1 works with the AWS default
  (`default.redis7`); forcing a custom group adds no value here. Documented, not created.
- **auth_token**: optional, `sensitive`, default `null`. When null it is NOT configured
  (so the arg is set via a conditional expression that yields `null`). Documented that it is
  recommended for prod. Never exposed in outputs.

## Validation-scenario coherence (MUST hold)

The module must validate cleanly for BOTH:
- (a) `num_cache_clusters = 2`, `automatic_failover_enabled = true`, `multi_az_enabled = true`.
- (b) `num_cache_clusters = 1`, `automatic_failover_enabled = false`, `multi_az_enabled = false`.

To avoid conflicts, variable `validation` blocks reference ONLY their own variable (Terraform
forbids cross-variable references in `validation` conditions anyway). Cross-field coherence
(e.g. "failover requires >= 2 nodes", "multi_az requires failover") is NOT enforced via
validation. Instead the resource derives the safe effective values with locals so case (b)
never trips AWS-side errors:
- `local.effective_failover = var.num_cache_clusters > 1 ? var.automatic_failover_enabled : false`
- `local.effective_multi_az  = local.effective_failover ? var.multi_az_enabled : false`
This makes case (b) valid even if a caller left failover/multi_az at their `true` defaults while
setting `num_cache_clusters = 1`. Document this clamping in a comment.

## replication_group_id 40-char limit enforcement

AWS limit: `replication_group_id` max 40 chars, lowercase letters/digits/hyphens, must start with
a letter, no consecutive/trailing hyphens. The raw name is `cb-${var.environment}-elasticache-${var.name}`.
Worst case `cb-prod-elasticache-` = 20 chars, leaving 20 for `var.name`.

Enforcement = validate the INPUT `var.name` so the composed id is always legal, in `variables.tf`:
```hcl
variable "name" {
  type        = string
  default     = "core"
  description = "Functionality segment ({funcionalidad}) for naming, e.g. 'core'. Lowercase letters, digits and hyphens; must keep the composed replication_group_id <= 40 chars."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "name must start with a lowercase letter and contain only lowercase letters, digits, and hyphens."
  }
  validation {
    condition     = length("cb-elasticache-${var.name}") <= 36
    error_message = "name too long: the composed replication_group_id (cb-{env}-elasticache-{name}) must be <= 40 chars; keep name short (prod uses the longest env prefix)."
  }
}
```
Rationale for the `36` constant: the longest env is `prod` (4) vs the literal fragment used in the
check (`cb-elasticache-` = 15). The real id adds `-${environment}` so the longest real prefix is
`cb-prod-elasticache-` (20). Using `length("cb-elasticache-${var.name}") <= 36` is equivalent to
`length(name) <= 21`, and `20 + 21 = 41` would exceed — so set the literal so the budget is 20:
use `length("cb-prod-elasticache-${var.name}") <= 40` directly instead (clearer). FINAL rule to
implement (unambiguous, no guessing):
```hcl
  validation {
    condition     = length("cb-prod-elasticache-${var.name}") <= 40
    error_message = "name too long: composed replication_group_id 'cb-{env}-elasticache-{name}' must be <= 40 chars (prod has the longest prefix)."
  }
```
This guarantees every environment stays within 40 chars because `prod` is the longest prefix.
Additionally, in `locals.tf` compute the id once and keep it lowercase (inputs already validated):
`replication_group_id = lower("${local.base_name}-elasticache-${var.name}")`.

## Validation harness (MANDATORY — used by every verify step)

`terraform` is v1.15.0 and available. `tflint` is NOT assumed installed. Verification relies on
`terraform init -backend=false` + `terraform validate` + `terraform fmt -check`.

1. Create a temp dir `/tmp/ec-validate/`.
2. Write `/tmp/ec-validate/main.tf` declaring a concrete AWS provider and calling the module:
   ```hcl
   terraform {
     required_providers {
       aws = { source = "hashicorp/aws", version = ">= 5.0.0" }
     }
   }
   provider "aws" {
     alias                       = "project"
     region                      = "us-west-2"
     skip_credentials_validation = true
     skip_requesting_account_id  = true
     skip_metadata_api_check     = true
   }
   module "test" {
     source = "<ROOT>/modules/elasticache"
     providers = { aws.project = aws.project }

     project     = "cb"
     environment = "prod"
     aws_region  = "us-west-2"

     name       = "core"
     vpc_id     = "vpc-0123456789abcdef0"
     subnet_ids = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]

     allowed_security_group_ids = ["sg-0123456789abcdef0"]
   }
   ```
   (Variant A = defaults: `num_cache_clusters=2`, failover/multi_az at `true` default, no kms_key_arn, no auth_token.)
3. Run: `cd /tmp/ec-validate && terraform init -backend=false && terraform validate`.
   Expected: `Success! The configuration is valid.`
4. Variant B (single-node): change the module call to `environment = "dev"`, add
   `num_cache_clusters = 1`, `automatic_failover_enabled = false`, `multi_az_enabled = false`,
   and pass `kms_key_arn = "arn:aws:kms:us-west-2:111122223333:key/abcd-ef01"`. Run
   `terraform validate` again — expected: `Success!` (confirms the dedicated-KMS branch is skipped
   and the single-node scenario validates with no cross-field conflict).
5. Variant C (auth + explicit size): set `auth_token = "aVeryLongAuthTokenValue1234567890"`,
   `node_type = "cache.r6g.large"`, `snapshot_retention_limit = 7`. Run `terraform validate` — expected `Success!`.
6. Run `terraform fmt -check -recursive "<ROOT>/modules/elasticache"` — expected: no files listed.
   Run `terraform fmt -recursive "<ROOT>/modules/elasticache"` to fix if it complains.
7. Delete `/tmp/ec-validate/` when done.

---

# Steps

- [ ] 1. Create `providers.tf`.
      Content: section separator header; `terraform { required_providers { aws = { configuration_aliases = [aws.project], source = "hashicorp/aws", version = ">= 5.0.0" } } }`. No backend. No kubernetes/helm. Mirror `modules/microservice/providers.tf` style.
      Files: modules/elasticache/providers.tf
      Verify: part of step 7 — `cd /tmp/ec-validate && terraform init -backend=false` resolves the provider.

- [ ] 2. Create `variables.tf` with all input variables, grouped by `###########################################` separators, descriptions in English.
      Files: modules/elasticache/variables.tf
      Variables (name — type — default — validation):
      - Common section:
        - `project` — string — (no default) — none.
        - `environment` — string — (no default) — `contains(["dev","qa","prod"], var.environment)` (error "Must be dev, qa, or prod.").
        - `aws_region` — string — (no default) — none.
      - Identity / networking section:
        - `name` — string — `"core"` — TWO validations exactly as in the "40-char limit" section above: regex `^[a-z][a-z0-9-]*$`, and `length("cb-prod-elasticache-${var.name}") <= 40`.
        - `vpc_id` — string — (no default, required) — `can(regex("^vpc-", var.vpc_id))` (error "vpc_id must be a valid VPC id (vpc-...).").
        - `subnet_ids` — list(string) — (no default, required) — `length(var.subnet_ids) >= 1` (error "subnet_ids must contain at least one private subnet id.").
      - Access control section:
        - `allowed_security_group_ids` — list(string) — `[]` — none.
        - `allowed_cidr_blocks` — list(string) — `[]` — `alltrue([for c in var.allowed_cidr_blocks : can(cidrhost(c, 0))])` (error "allowed_cidr_blocks must be valid CIDR blocks.").
      - KMS section:
        - `kms_key_arn` — string — `null` — none (when null a dedicated CMK is created).
      - Engine / sizing section:
        - `engine_version` — string — `"7.1"` — `can(regex("^[0-9]+\\.[0-9x]+$", var.engine_version))` (error "engine_version must look like '7.1' or '6.x'.").
        - `node_type` — string — `"cache.r6g.large"` — `can(regex("^cache\\.", var.node_type))` (error "node_type must be a valid ElastiCache node type (cache.*).").
        - `num_cache_clusters` — number — `2` — `var.num_cache_clusters >= 1 && var.num_cache_clusters <= 6` (error "num_cache_clusters must be between 1 and 6 (cluster-mode-disabled).").
        - `automatic_failover_enabled` — bool — `true` — none. (Doc comment: effectively clamped to false when num_cache_clusters == 1 via locals.)
        - `multi_az_enabled` — bool — `true` — none. (Doc comment: effectively clamped to false when failover is off.)
        - `snapshot_retention_limit` — number — `5` — `var.snapshot_retention_limit >= 0 && var.snapshot_retention_limit <= 35` (error "snapshot_retention_limit must be between 0 and 35.").
        - `maintenance_window` — string — `"sun:05:00-sun:07:00"` — none.
        - `apply_immediately` — bool — `false` — none.
      - Auth section:
        - `auth_token` — string — `null` — `sensitive = true` — validation using `can(...)`: when non-null, length 16–128, e.g. `condition = var.auth_token == null ? true : (length(var.auth_token) >= 16 && length(var.auth_token) <= 128)` (error "auth_token must be 16-128 chars when set."). Note: auth_token requires transit encryption, which this module always enables.
      - Tags section:
        - `additional_tags` — map(string) — `{}` — none.
      Verify: deferred to step 7 (`terraform validate`).

- [ ] 3. Create `locals.tf` with naming and derived values.
      Files: modules/elasticache/locals.tf
      Locals:
      - `base_name = "cb-${var.environment}"`
      - `replication_group_id = lower("${local.base_name}-elasticache-${var.name}")`  (component literal `elasticache`)
      - `subnet_group_name = "${local.base_name}-elasticache-${var.name}"`
      - `sg_name = "${local.base_name}-sg-elasticache-${var.name}"`  (SG component literal `sg`, then qualifier `elasticache`)
      - `kms_key_name = "${local.base_name}-kms-elasticache-${var.name}"`  (KMS component literal `kms`)
      - `kms_alias = "alias/${local.base_name}-kms-elasticache-${var.name}"`
      - `create_kms = var.kms_key_arn == null`
      - `kms_key_arn = local.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn`  (effective CMK used everywhere)
      - `effective_failover = var.num_cache_clusters > 1 ? var.automatic_failover_enabled : false`
      - `effective_multi_az = local.effective_failover ? var.multi_az_enabled : false`
      Include a header comment restating the naming pattern (mirror microservice/cloudfront locals.tf).
      Verify: deferred to step 7.

- [ ] 4. Create `main.tf` — section 1 data + KMS. Add a module header comment block. Add `data "aws_caller_identity" "current" { provider = aws.project }` (used for the KMS key policy root principal). Then the dedicated CMK, created only when `local.create_kms`:
      - `aws_kms_key "this"` — `provider = aws.project`, `count = local.create_kms ? 1 : 0`, `description = "KMS CMK for ElastiCache Redis ${local.replication_group_id}"`, `enable_key_rotation = true` (never skip CKV_AWS_7), `deletion_window_in_days = 30`, `policy = jsonencode(...)` with the root-account `kms:*` statement from security.md (`Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }`), `tags = merge({ Name = local.kms_key_name }, var.additional_tags)`.
      - `aws_kms_alias "this"` — `provider = aws.project`, `count = local.create_kms ? 1 : 0`, `name = local.kms_alias`, `target_key_id = aws_kms_key.this[0].key_id`.
      Files: modules/elasticache/main.tf
      Verify: deferred to step 7.

- [ ] 5. Append to `main.tf` — section 2 networking (subnet group + security group).
      - `aws_elasticache_subnet_group "this"` — `provider = aws.project`, `name = local.subnet_group_name`, `subnet_ids = var.subnet_ids`, `description = "Private subnets for ${local.replication_group_id}"`, `tags = merge({ Name = local.subnet_group_name }, var.additional_tags)`.
      - `aws_security_group "this"` — `provider = aws.project`, `name = local.sg_name`, `description = "Redis 6379 access for ${local.replication_group_id}"`, `vpc_id = var.vpc_id`. Ingress via nested dynamic blocks so empty lists create no rule (so no public access is ever opened):
        - `dynamic "ingress"` over `[for sg in var.allowed_security_group_ids : sg]` → `from_port = 6379`, `to_port = 6379`, `protocol = "tcp"`, `security_groups = [ingress.value]`, `description = "Redis from allowed SG"`.
        - `dynamic "ingress"` over `length(var.allowed_cidr_blocks) > 0 ? [1] : []` → single rule `from_port = 6379`, `to_port = 6379`, `protocol = "tcp"`, `cidr_blocks = var.allowed_cidr_blocks`, `description = "Redis from allowed CIDRs"`.
        - `egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]; description = "Allow all outbound" }` with `# checkov:skip=CKV_AWS_382: Egress abierto requerido para DNS/healthchecks del cluster; ingress está restringido a 6379`.
        - `tags = merge({ Name = local.sg_name }, var.additional_tags)`.
      Files: modules/elasticache/main.tf
      Verify: deferred to step 7.

- [ ] 6. Append to `main.tf` — section 3 the Redis replication group.
      - `aws_elasticache_replication_group "this"` — `provider = aws.project`. Add checkov skips as needed, e.g. `# checkov:skip=CKV_AWS_191:CMK dedicada se usa vía kms_key_id` only if a false positive appears; otherwise none. Arguments:
        - `replication_group_id       = local.replication_group_id`
        - `description                = "Core Bancario Redis - ${var.name} (${var.environment})"`
        - `engine                     = "redis"`
        - `engine_version             = var.engine_version`
        - `node_type                  = var.node_type`
        - `port                       = 6379`
        - `num_cache_clusters         = var.num_cache_clusters`  (cluster-mode-disabled: 1 primary + (N-1) replicas)
        - `automatic_failover_enabled = local.effective_failover`
        - `multi_az_enabled           = local.effective_multi_az`
        - `subnet_group_name          = aws_elasticache_subnet_group.this.name`
        - `security_group_ids         = [aws_security_group.this.id]`
        - `at_rest_encryption_enabled = true`
        - `kms_key_id                 = local.kms_key_arn`
        - `transit_encryption_enabled = true`
        - `auth_token                 = var.auth_token`  (null when unset → not configured; requires transit encryption which is always on)
        - `snapshot_retention_limit   = var.snapshot_retention_limit`
        - `maintenance_window         = var.maintenance_window`
        - `apply_immediately          = var.apply_immediately`
        - `tags = merge({ Name = local.replication_group_id }, var.additional_tags)`
      - Add a comment documenting: cluster-mode-disabled; `num_cache_clusters` = total nodes (primary + replicas); default 2 = 1 primary + 1 replica; parameter group intentionally omitted (uses AWS `default.redis7`); `auth_token` recommended for prod, left null otherwise.
      Files: modules/elasticache/main.tf
      Verify: deferred to step 7.

- [ ] 7. Create `outputs.tf` and run the full validation harness.
      Files: modules/elasticache/outputs.tf
      Outputs (each with `description`):
      - `replication_group_id`     = `aws_elasticache_replication_group.this.id`
      - `replication_group_arn`    = `aws_elasticache_replication_group.this.arn`
      - `primary_endpoint_address` = `aws_elasticache_replication_group.this.primary_endpoint_address`
      - `reader_endpoint_address`  = `aws_elasticache_replication_group.this.reader_endpoint_address`
      - `port`                     = `6379`
      - `security_group_id`        = `aws_security_group.this.id`
      - `kms_key_arn`              = `local.kms_key_arn`  (effective CMK, created or passed)
      Do NOT output `auth_token`.
      Then run the Validation harness (variants A, B, C) and `terraform fmt -check -recursive`.
      Verify: `terraform validate` prints `Success! The configuration is valid.` for all three variants (A defaults/2-node/dedicated-KMS, B single-node/passed-KMS, C auth+explicit-size), and `terraform fmt -check -recursive "<ROOT>/modules/elasticache"` lists no files. Fix any module files until all pass. Delete `/tmp/ec-validate/` afterward.

---

## Notes / assumptions

- No layer or tfvars work is in scope; per-environment sizing (large prod / medium qa / small dev)
  is achieved by the caller passing `node_type`, `num_cache_clusters`, `snapshot_retention_limit`,
  `multi_az_enabled` from each env's tfvars later — the module only exposes the knobs.
- Checkov is advisory in this repo; `checkov:skip` comments are added where a risk is accepted
  (egress-all). KMS rotation and encryption-at-rest/in-transit are never skipped.
- `terraform` v1.15.0 available; `tflint` not assumed. Verification = `terraform validate` + `terraform fmt -check`.
- Checkov check IDs in skip comments are best-effort; the implementer should replace a wrong ID
  with the one Checkov actually reports if a scan is run, keeping the Spanish justification.
