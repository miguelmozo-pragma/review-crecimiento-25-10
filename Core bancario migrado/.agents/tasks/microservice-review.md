# Review — `microservice` reusable Terraform module

Scope: `modules/microservice/` reviewed against `.agents/tasks/microservice-plan.md`,
`.kiro/steering/create-module.md`, and `.kiro/steering/naming-conventions.md`.

Verdict: **CHANGES_REQUESTED** — one blocking finding (missing required verification evidence).

## Evidence report

- Files present: `providers.tf`, `variables.tf`, `locals.tf`, `main.tf`, `ecr.tf`,
  `iam.tf`, `k8s.tf`, `pipeline.tf`, `outputs.tf`. Layout matches the plan's per-domain split.
- Module files are unchanged since the previous review pass (all mtimes 19:16–19:18,
  earlier than the prior review outputs at 19:22). No new coder activity has occurred:
  no new evidence file under `.agents/`, no git repository/commit, and the validate
  harness directories (`/tmp/microservice-validate`, `/tmp/ms-validate`) do not exist.
- Verification I could confirm directly: `terraform fmt -check -recursive modules/microservice`
  returns clean (exit 0, no files listed) — the permitted narrow spot-check.
- Verification I could NOT confirm: the required `terraform validate` →
  "Success! The configuration is valid." There is no coder final/commit message, report,
  notes, or log recording that run anywhere I can read. See Finding 1.
- Harness cleanup: `/tmp/microservice-validate` and `/tmp/ms-validate` do not exist — deleted. Good.
- Blast radius: only `modules/microservice/*.tf` carry task mtimes (19:16–19:18). No
  microservice tfvars/layer files were created and no other modules/layers
  (`modules/eks`, `modules/vpc-module`, `layers/*`, `*.tfvars`) were touched. Good.

## Requirement-by-requirement check

(a) Layout + providers.tf — PASS. `required_providers` declares `aws`
(`hashicorp/aws`, `>= 5.0.0`, `configuration_aliases = [aws.project]`) and
`kubernetes` (`hashicorp/kubernetes`, `>= 2.10`). No backend. No helm/kubectl. No cicd alias.

(b) Common variables — PASS. `project`, `environment` (validation
`contains(["dev","qa","prod"], ...)`), `aws_region`, and `additional_tags` present.
Descriptions in English. Variables grouped with `###########################################`
separators by domain.

(c) Locals naming — PASS. `base_name = "cb-${var.environment}"`; names use literal
component segments: `ecr`, `role`, `policy`, and pipeline `cb-{env}-pipeline-{service}`.
Lowercase + hyphens only, no underscores in resource names. `service_name` is validated
`^[a-z0-9-]+$`, protecting the funcionalidad segment.

(d) `provider = aws.project` + tags — PASS. Every AWS resource sets
`provider = aws.project` and `tags = merge({ Name = local.* }, var.additional_tags)`
(ECR repo, IRSA role, pipeline/codebuild roles, access entry, CodeBuild project,
CodePipeline). `aws_ecr_lifecycle_policy` and `aws_iam_role_policy` are AWS sub-resources
without a tags argument (correct — they do not support tags).

(e) ECR — PASS. `aws_ecr_repository.this` with `scan_on_push = true`, conditional
`encryption_type = KMS/AES256` driven by `var.kms_key_arn`, plus
`aws_ecr_lifecycle_policy.this` expiring images beyond `var.ecr_max_image_count`.

(f) IRSA — PASS. Federated trust on `var.oidc_provider_arn`,
`sts:AssumeRoleWithWebIdentity`, `Condition.StringEquals` with dynamic
`"${var.oidc_provider_url}:sub"` = `system:serviceaccount:<ns>:<sa>` and `:aud` =
`sts.amazonaws.com`. Inline policy `aws_iam_role_policy.irsa` gated by
`length(var.policy_statements) > 0 ? 1 : 0`.

(g) Kubernetes — PASS. Uses the `_v1` variants only
(`kubernetes_service_account_v1`, `kubernetes_deployment_v1`, `kubernetes_service_v1`,
`kubernetes_ingress_v1`). SA annotated with the IRSA role ARN. Ingress gated by
`count = var.create_ingress ? 1 : 0`.

(h) Pipeline — PASS. Single-account: no `aws.cicd`, no cross-account assume-role, no
DR project/stage, no SonarQube Secrets statement. CodePipeline + CodeBuild roles and
inline policies, ECR auth/push + `eks:DescribeCluster`, optional
`aws_eks_access_entry` + `aws_eks_access_policy_association`
(`AmazonEKSEditPolicy`, namespace scope) gated by `create_pipeline && grant_eks_access`.
CodeBuild `privileged_mode = true`, the specified env vars plus a dynamic block over
`pipeline_environment_variables`. All pipeline resources use `provider = aws.project`
and are gated by `create_pipeline`.

(i) Outputs — PASS. All required outputs present, each with a `description`:
`ecr_repository_url/arn/name`, `irsa_role_arn/name`, `service_account_name`,
`deployment_name`, `service_name`, `service_cluster_ip`, `ingress_hostname`
(try-guarded), `pipeline_name`, `codebuild_project_name` (null when disabled).

## Findings (blockers only)

### Finding 1 — Required `terraform validate` evidence is missing (BLOCKER)

- Requirement: the module MUST pass `terraform validate` via the throwaway harness, and
  the review step must confirm the coder recorded
  "Success! The configuration is valid." from that run. The step prompt states that if
  that evidence is missing, reject with a finding.
- Observation: no such evidence is available to read on this pass. The module files are
  unchanged since the previous review (mtimes 19:16–19:18, prior review 19:22), and no new
  coder artifact exists: there is no git repository (so no commit message), no coder
  report/notes/log anywhere under `.agents/` (only `microservice-plan.md` and the prior
  review outputs), and no recorded validate output. The permitted narrow spot-check
  (`terraform fmt -check -recursive modules/microservice`) passes, but formatting is not a
  substitute for `terraform validate`, and re-running the validate harness is out of scope.
- Consequence: the mandatory verification gate for this task is unsatisfied. The module's
  static read is internally consistent and matches every plan requirement, but without the
  recorded validate result there is no confirmation the configuration actually validates,
  so approval cannot be granted.
- Correction: run the validate harness as described in the plan's "Validation harness"
  section (both the minimal-vars variant and the fully-enabled variant with
  `create_ingress = true`, `create_pipeline = true`, a dummy connection/repo/bucket, and a
  non-empty `policy_statements`), and record the exact
  "Success! The configuration is valid." output in the coder's final message (and a commit
  message if the repo is placed under version control) so this reviewer can read it.
  Delete the harness afterward.
