# Implementation Plan — `microservice` reusable Terraform module

Goal: a reusable module at `modules/microservice/` that deploys EVERY resource for a microservice on EKS: (1) ECR repo, (2) IRSA IAM role + annotated Kubernetes ServiceAccount, (3) parameterizable Kubernetes Deployment/Service/Ingress, and (4) a SINGLE-ACCOUNT CI/CD pipeline (CodePipeline + CodeBuild) that builds a Docker image, pushes it to ECR, and updates the EKS deployment. No cross-account, no DR, no SonarQube stage.

All paths are absolute under the workspace root:
`/home/miguel-mozo/Documents/Review de crecimiento/Terraform iac/Core bancario migrado`
(abbreviated below as `<ROOT>`).

## Design decisions (made here, grounded in the repo)

- **File split.** Follow the repo convention (create-module.md): `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `providers.tf`. The lambda reference splits the pipeline into `pipeline.tf`; this module has three resource domains (AWS infra, IAM, Kubernetes, pipeline), so split into `ecr.tf`, `iam.tf` (IRSA role), `k8s.tf` (SA + Deployment + Service + Ingress), and `pipeline.tf` (CodePipeline/CodeBuild + their IAM + EKS access entry). `main.tf` holds only shared `data` sources (e.g. `aws_caller_identity`) and a header comment; this keeps each file focused and matches the lambda reference's use of per-domain files. Rationale: the EKS module already uses per-domain files (`iam.tf`, `addons.tf`, `karpenter.tf`), so this matches established repo style.
- **Providers.** `aws` with `configuration_aliases = [aws.project]` (version `>= 5.0.0`) and `kubernetes` (`>= 2.10`). Do NOT declare `helm` or `kubectl` — no Helm releases or raw manifests are created here (the EKS module owns those). Rationale: tech.md + create-module.md require kubernetes alias for k8s resources; helm/kubectl are unused.
- **Single-account simplification vs lambda reference.** REMOVE the `aws.cicd` alias and every `provider = aws.cicd`, REMOVE `deploy_cross_account` role + its `sts:AssumeRole` chain, REMOVE all `dr_*` variables / `dr_deploy` CodeBuild project / `Deploy_DR` stage, and REMOVE the hardcoded SonarQube `SecretsManager` statement (`arn:aws:secretsmanager:us-east-1:...:/spos/sonar/*`). All pipeline resources use `provider = aws.project`. The CodeBuild role gets its deploy permissions directly (ECR push + `eks:DescribeCluster` + an EKS access entry) instead of assuming a cross-account role. Rationale: user explicitly requires single-account local-deploy; task constraints forbid cross-account/DR/Sonar.
- **How CodeBuild reaches the cluster.** Grant the CodeBuild role `eks:DescribeCluster` (IAM) plus an `aws_eks_access_entry` + `aws_eks_access_policy_association` binding the role to `AmazonEKSEditPolicy` scoped to `namespace var.namespace`. This replaces IAM-side kube access with the modern EKS Access Entries API (the EKS module uses `authentication_mode` access entries already). Gated by `grant_eks_access` (default `true`) and `create_pipeline`. Rationale: single-account EKS deploy needs the build role mapped into the cluster; access entries avoid editing `aws-auth`.
- **Deprecation avoidance.** Use the `_v1` kubernetes resources only: `kubernetes_service_account_v1`, `kubernetes_deployment_v1`, `kubernetes_service_v1`, `kubernetes_ingress_v1`. Do NOT use the pre-1.0 unversioned resources.
- **Component literals in names.** `ecr`, `role`, `policy` are literal segments in `locals.tf`; pipeline uses the naming-conventions.md pattern `cb-{env}-pipeline-{service_name}`. Names are lowercase+hyphens only, ≤63 chars.

## Validation harness (MANDATORY — used by every verify step)

There are no build/test scripts in this repo (tech.md) and a module cannot be `terraform plan`'d without a root/provider config. So verification uses a throwaway harness that is DELETED after each check (never committed):

1. Create a temp dir, e.g. `/tmp/ms-validate/`.
2. Write `/tmp/ms-validate/main.tf` that: declares `terraform { required_providers { aws = { source = "hashicorp/aws", configuration_aliases=[] }, kubernetes = {...} } }` with concrete `provider "aws" { alias = "project"; region = "us-west-2" }` and `provider "kubernetes" {}` blocks, then calls `module "test" { source = "<ROOT>/modules/microservice"; providers = { aws.project = aws.project, kubernetes = kubernetes }; project = "cb"; environment = "dev"; aws_region = "us-west-2"; service_name = "frontend"; namespace = "frontend"; oidc_provider_arn = "arn:aws:iam::111122223333:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/ABC"; oidc_provider_url = "oidc.eks.us-west-2.amazonaws.com/id/ABC"; cluster_name = "cb-dev-eks-core" }` — i.e. only required vars, pipeline/ingress left at their `false` defaults.
3. Run: `cd /tmp/ms-validate && terraform init -backend=false && terraform validate`.
4. Expected outcome: `Success! The configuration is valid.`
5. Add a second harness variant that also sets `create_ingress = true`, `create_pipeline = true` (with dummy `codestar_connection_arn`, `pipeline_repository = "owner/repo"`, `pipeline_artifact_bucket_name = "cb-dev-artifacts"`), `policy_statements = [{ sid="S3", effect="Allow", actions=["s3:GetObject"], resources=["*"] }]`, and run `terraform validate` again — same expected outcome. This exercises every `count`-gated resource path.
6. Run `terraform fmt -check -recursive <ROOT>/modules/microservice` — expected: no files listed (all formatted). Run `terraform fmt -recursive` to fix if it complains.
7. Delete `/tmp/ms-validate/` when done.

`tflint` is NOT installed; do not rely on it. `terraform validate` + `terraform fmt -check` are the verification commands for every step below.

---

# Implementation Plan

- [ ] 1. Create `modules/microservice/providers.tf` with the terraform/required_providers block.
      Declare `aws` (`source = "hashicorp/aws"`, `version = ">= 5.0.0"`, `configuration_aliases = [aws.project]`) and `kubernetes` (`source = "hashicorp/kubernetes"`, `version = ">= 2.10"`). No backend. No helm/kubectl. No cicd alias.
      Files: `modules/microservice/providers.tf`
      Verify: part of the init step — `cd /tmp/ms-validate && terraform init -backend=false` succeeds (provider requirements resolve). Full `terraform validate` runs in step 9.

- [ ] 2. Create `modules/microservice/variables.tf` with all input variables, grouped by `###########################################` separators, English descriptions, validations where applicable.
      Groups and variables:
      - Common: `project` (string), `environment` (string, validation `contains(["dev","qa","prod"], var.environment)`), `aws_region` (string).
      - Service identity: `service_name` (string, the `{funcionalidad}` segment, e.g. "frontend"; validation `can(regex("^[a-z0-9-]+$", var.service_name))`), `namespace` (string), `service_account_name` (string, `default = ""` → locals default to `service_name`).
      - ECR: `image_tag_mutability` (string, default `"IMMUTABLE"`, validation `contains(["MUTABLE","IMMUTABLE"], ...)`), `ecr_max_image_count` (number, default 10, validation `>= 1`), `kms_key_arn` (string, default `null`).
      - IRSA: `oidc_provider_arn` (string), `oidc_provider_url` (string, no `https://`), `policy_statements` (`list(object({ sid=string, effect=string, actions=list(string), resources=list(string) }))`, default `[]`).
      - Deployment: `image` (string, default `""` → locals default to `"${repo_url}:latest"`), `replicas` (number, default 1, validation `>= 1`), `container_port` (number, default 8080), `resources_requests` (`map(string)`, default `{ cpu="256m", memory="256Mi" }`), `resources_limits` (`map(string)`, default `{ cpu="512m", memory="512Mi" }`), `env` (`map(string)`, default `{}`).
      - Service: `service_type` (string, default `"ClusterIP"`, validation `contains(["ClusterIP","NodePort","LoadBalancer"], ...)`), `service_port` (number, default 80).
      - Ingress: `create_ingress` (bool, default false), `ingress_class_name` (string, default `"alb"`), `ingress_annotations` (`map(string)`, default `{}`), `ingress_host` (string, default `""`), `ingress_path` (string, default `"/"`), `ingress_path_type` (string, default `"Prefix"`, validation `contains(["Prefix","Exact","ImplementationSpecific"], ...)`).
      - Pipeline: `create_pipeline` (bool, default false), `codestar_connection_arn` (string, default null), `pipeline_repository` (string, default "", format owner/repo), `pipeline_branch` (string, default "main"), `pipeline_buildspec` (string, default "buildspec.yml"), `pipeline_compute_type` (string, default "BUILD_GENERAL1_SMALL", validation `contains(["BUILD_GENERAL1_SMALL","BUILD_GENERAL1_MEDIUM","BUILD_GENERAL1_LARGE"], ...)`), `pipeline_build_image` (string, default `"aws/codebuild/amazonlinux2-x86_64-standard:5.0"`), `pipeline_artifact_bucket_name` (string, default null), `pipeline_environment_variables` (`list(object({ name=string, value=string, type=string }))`, default `[]`), `grant_eks_access` (bool, default true), `cluster_name` (string).
      - Tags: `additional_tags` (`map(string)`, default `{}`).
      Files: `modules/microservice/variables.tf`
      Verify: deferred to step 9 (`terraform validate` on the harness). This item leaves the module uncompilable alone (expected) until resources exist.

- [ ] 3. Create `modules/microservice/locals.tf` with `base_name` and all computed names.
      `base_name = "cb-${var.environment}"`. Names (all literal component segments):
      - `ecr_repo_name = "${local.base_name}-ecr-${var.service_name}"`
      - `irsa_role_name = "${local.base_name}-role-${var.service_name}"`
      - `irsa_policy_name = "${local.base_name}-policy-${var.service_name}"`
      - `pipeline_name = "cb-${var.environment}-pipeline-${var.service_name}"`
      - `codebuild_name = "cb-${var.environment}-pipeline-${var.service_name}-build"`
      - `pipeline_role_name = "cb-${var.environment}-pipeline-${var.service_name}-pl-role"`
      - `codebuild_role_name = "cb-${var.environment}-pipeline-${var.service_name}-cb-role"`
      Also computed convenience locals: `service_account_name = var.service_account_name != "" ? var.service_account_name : var.service_name`; `app_label = var.service_name`; `container_image = var.image != "" ? var.image : "${aws_ecr_repository.this.repository_url}:latest"` (references the ECR resource from step 4 — ensures image defaults to the created repo). Add a short comment block explaining the naming convention (mirroring `modules/eks/locals.tf`).
      Files: `modules/microservice/locals.tf`
      Verify: deferred to step 9.

- [ ] 4. Create `modules/microservice/ecr.tf` with the ECR repository and lifecycle policy.
      `aws_ecr_repository "this"`: `provider = aws.project`, `name = local.ecr_repo_name`, `image_tag_mutability = var.image_tag_mutability`, `image_scanning_configuration { scan_on_push = true }`, and `encryption_configuration { encryption_type = var.kms_key_arn != null ? "KMS" : "AES256"; kms_key = var.kms_key_arn }`, `tags = merge({ Name = local.ecr_repo_name }, var.additional_tags)`. `aws_ecr_lifecycle_policy "this"`: `repository = aws_ecr_repository.this.name`, policy JSON keeping the most recent `var.ecr_max_image_count` images (rule 1, `countType = "imageCountMoreThan"`, `countNumber = var.ecr_max_image_count`, `tagStatus = "any"`, action `expire`).
      Files: `modules/microservice/ecr.tf`
      Verify: deferred to step 9.

- [ ] 5. Create `modules/microservice/iam.tf` with the IRSA role and optional inline policy.
      `aws_iam_role "irsa"`: `provider = aws.project`, `name = local.irsa_role_name`, `tags = merge({ Name = local.irsa_role_name }, var.additional_tags)`, and `assume_role_policy = jsonencode(...)` with the standard IRSA federated trust:
      ```json
      {
        "Version": "2012-10-17",
        "Statement": [{
          "Sid": "AllowEKSIRSA",
          "Effect": "Allow",
          "Principal": { "Federated": "<var.oidc_provider_arn>" },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              "<var.oidc_provider_url>:sub": "system:serviceaccount:<var.namespace>:<local.service_account_name>",
              "<var.oidc_provider_url>:aud": "sts.amazonaws.com"
            }
          }
        }]
      }
      ```
      Build the `Condition.StringEquals` map with dynamic keys using `"${var.oidc_provider_url}:sub"` / `"${var.oidc_provider_url}:aud"`.
      `aws_iam_role_policy "irsa"` with `count = length(var.policy_statements) > 0 ? 1 : 0`: `provider = aws.project`, `name = local.irsa_policy_name`, `role = aws_iam_role.irsa.id`, `policy = jsonencode({ Version = "2012-10-17", Statement = [for s in var.policy_statements : { Sid = s.sid, Effect = s.effect, Action = s.actions, Resource = s.resources }] })`. When the list is empty the inline policy is NOT created.
      Files: `modules/microservice/iam.tf`
      Verify: deferred to step 9.

- [ ] 6. Create `modules/microservice/k8s.tf` with the ServiceAccount, Deployment, Service, and conditional Ingress (all `_v1`).
      - `kubernetes_service_account_v1 "this"`: `metadata { name = local.service_account_name, namespace = var.namespace, annotations = { "eks.amazonaws.com/role-arn" = aws_iam_role.irsa.arn } }`.
      - `kubernetes_deployment_v1 "this"`: `metadata { name = var.service_name, namespace = var.namespace, labels = { app = local.app_label } }`; spec `replicas = var.replicas`, `selector { match_labels = { app = local.app_label } }`, template with `labels = { app = local.app_label }`, `spec { service_account_name = kubernetes_service_account_v1.this.metadata[0].name; container { name = var.service_name, image = local.container_image, port { container_port = var.container_port }, resources { requests = var.resources_requests, limits = var.resources_limits }, dynamic "env" { for_each = var.env; content { name = env.key, value = env.value } } } }`.
      - `kubernetes_service_v1 "this"`: `metadata { name = var.service_name, namespace = var.namespace }`, spec `selector = { app = local.app_label }`, `type = var.service_type`, `port { port = var.service_port, target_port = var.container_port }`.
      - `kubernetes_ingress_v1 "this"` with `count = var.create_ingress ? 1 : 0`: `metadata { name = var.service_name, namespace = var.namespace, annotations = var.ingress_annotations }`, spec `ingress_class_name = var.ingress_class_name`, `rule { host = var.ingress_host != "" ? var.ingress_host : null, http { path { path = var.ingress_path, path_type = var.ingress_path_type, backend { service { name = kubernetes_service_v1.this.metadata[0].name, port { number = var.service_port } } } } } }`.
      Files: `modules/microservice/k8s.tf`
      Verify: deferred to step 9.

- [ ] 7. Create `modules/microservice/pipeline.tf` with the SINGLE-ACCOUNT CodePipeline + CodeBuild stack. Every resource is `provider = aws.project` and gated by `count = var.create_pipeline ? 1 : 0` (except the EKS access entry, see below). Adapt from the lambda `pipeline.tf` but with ALL `aws.cicd`, cross-account deploy role, DR project/stage, and SonarQube Secrets statement REMOVED.
      - `data "aws_caller_identity" "current"` (provider `aws.project`) for account id in ARNs.
      - CodePipeline role `aws_iam_role "pipeline"` (name `local.pipeline_role_name`, trust `codepipeline.amazonaws.com`) + `aws_iam_role_policy "pipeline"` with statements: S3 artifact bucket (get/put on `arn:aws:s3:::${var.pipeline_artifact_bucket_name}` and `/*`), `codestar-connections:UseConnection` on `var.codestar_connection_arn`, `codebuild:StartBuild`/`BatchGetBuilds` on `aws_codebuild_project.this[0].arn`.
      - CodeBuild role `aws_iam_role "codebuild"` (name `local.codebuild_role_name`, trust `codebuild.amazonaws.com`) + `aws_iam_role_policy "codebuild"` with statements: CloudWatch Logs (create group/stream + put events on `/aws/codebuild/${local.codebuild_name}*`), S3 artifacts get/put, `codestar-connections:UseConnection` on the connection, `ecr:GetAuthorizationToken` on `"*"`, ECR push/pull (`BatchCheckLayerAvailability`, `GetDownloadUrlForLayer`, `BatchGetImage`, `PutImage`, `InitiateLayerUpload`, `UploadLayerPart`, `CompleteLayerUpload`) scoped to `aws_ecr_repository.this.arn`, and `eks:DescribeCluster` on the cluster ARN (`arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}`).
      - `aws_eks_access_entry "codebuild"` and `aws_eks_access_policy_association "codebuild"` with `count = var.create_pipeline && var.grant_eks_access ? 1 : 0`: entry `cluster_name = var.cluster_name`, `principal_arn = aws_iam_role.codebuild[0].arn`; association `policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"`, `access_scope { type = "namespace", namespaces = [var.namespace] }`. Add a comment documenting that this grants the build role kube edit rights scoped to the namespace.
      - `aws_codebuild_project "this"`: `service_role = aws_iam_role.codebuild[0].arn`, `artifacts { type = "CODEPIPELINE" }`, `environment { compute_type = var.pipeline_compute_type, image = var.pipeline_build_image, type = "LINUX_CONTAINER", privileged_mode = true }` with `environment_variable` blocks for `ECR_REPO_NAME` (=`local.ecr_repo_name`), `ECR_REPO_URL` (=`aws_ecr_repository.this.repository_url`), `AWS_REGION` (=`var.aws_region`), `AWS_ACCOUNT_ID` (=`data.aws_caller_identity.current.account_id`), `ENVIRONMENT` (=`var.environment`), `CLUSTER_NAME` (=`var.cluster_name`), `K8S_NAMESPACE` (=`var.namespace`), `SERVICE_NAME` (=`var.service_name`), plus a `dynamic "environment_variable"` over `var.pipeline_environment_variables`. `source { type = "CODEPIPELINE", buildspec = var.pipeline_buildspec }`.
      - `aws_codepipeline "this"`: `pipeline_type = "V2"`, `role_arn = aws_iam_role.pipeline[0].arn`, `artifact_store { location = var.pipeline_artifact_bucket_name, type = "S3" }`, Source stage (`CodeStarSourceConnection`, `ConnectionArn = var.codestar_connection_arn`, `FullRepositoryId = var.pipeline_repository`, `BranchName = var.pipeline_branch`, output `source_output`), Build stage (`CodeBuild`, `ProjectName = aws_codebuild_project.this[0].name`, input `source_output`).
      - All AWS resources carry `tags = merge({ Name = local.xxx }, var.additional_tags)`. Add a `#checkov:skip` with Spanish comment where a broad grant is intentional (e.g. `ecr:GetAuthorizationToken` on `*` — required by ECR API).
      Files: `modules/microservice/pipeline.tf`
      Verify: deferred to step 9.

- [ ] 8. Create `modules/microservice/outputs.tf` exposing all required outputs, each with `description`.
      Outputs: `ecr_repository_url` (=`aws_ecr_repository.this.repository_url`), `ecr_repository_arn`, `ecr_repository_name`, `irsa_role_arn` (=`aws_iam_role.irsa.arn`), `irsa_role_name`, `service_account_name` (=`kubernetes_service_account_v1.this.metadata[0].name`), `deployment_name` (=`kubernetes_deployment_v1.this.metadata[0].name`), `service_name` (=`kubernetes_service_v1.this.metadata[0].name`), `service_cluster_ip` (=`kubernetes_service_v1.this.spec[0].cluster_ip`), `ingress_hostname` (=`var.create_ingress ? try(kubernetes_ingress_v1.this[0].status[0].load_balancer[0].ingress[0].hostname, null) : null`), `pipeline_name` (=`var.create_pipeline ? aws_codepipeline.this[0].name : null`), `codebuild_project_name` (=`var.create_pipeline ? aws_codebuild_project.this[0].name : null`).
      Files: `modules/microservice/outputs.tf`
      Verify: deferred to step 9.

- [ ] 9. Validate the whole module with the throwaway harness (minimal-vars variant).
      Build `/tmp/ms-validate/main.tf` as described in the "Validation harness" section (minimal required vars, pipeline + ingress at `false` defaults), then run `cd /tmp/ms-validate && terraform init -backend=false && terraform validate`.
      Files: none in the module (harness is temp, outside the repo).
      Verify: `terraform validate` prints `Success! The configuration is valid.` Fix any errors in the module files until it passes.

- [ ] 10. Validate the fully-enabled paths with the harness (second variant) and check formatting.
      Edit the harness module call to also set `create_ingress = true`, `create_pipeline = true` (with dummy `codestar_connection_arn = "arn:aws:codestar-connections:us-west-2:111122223333:connection/abc"`, `pipeline_repository = "bgsas/cb-frontend"`, `pipeline_artifact_bucket_name = "cb-dev-s3-artifacts"`), `grant_eks_access = true`, and a non-empty `policy_statements`. Run `cd /tmp/ms-validate && terraform validate`. Then run `terraform fmt -check -recursive "<ROOT>/modules/microservice"` (run `terraform fmt -recursive` to fix if needed).
      Files: none in the module (harness is temp).
      Verify: `terraform validate` prints `Success! The configuration is valid.` for the enabled-paths variant, and `terraform fmt -check -recursive` lists no files. Delete `/tmp/ms-validate/` afterward.

## Notes / assumptions

- The module does NOT create the S3 artifact bucket, the CodeStar connection, or the KMS key — these are inputs (consistent with security.md: base IAM/KMS live in the security layer; modules receive ARNs). The ECR repo is created here (the EKS-migration repo has no shared ECR module wired yet and the task explicitly requires the repo inside this module).
- `oidc_provider_url` is passed separately because the EKS module only outputs `oidc_provider_arn`; the consuming layer will derive the URL (strip `https://` from `module.eks` cluster OIDC issuer) and pass both. This is noted for the layer step, which is out of scope here.
- Per task constraints, do NOT create tfvars or the `workload` layer wiring in this task — only the module under `modules/microservice/`. Do not modify `modules/eks` or `modules/vpc-module`.
- `terraform` is v1.15.0 and available; `tflint` is NOT installed — verification relies on `terraform validate` + `terraform fmt -check` only.
