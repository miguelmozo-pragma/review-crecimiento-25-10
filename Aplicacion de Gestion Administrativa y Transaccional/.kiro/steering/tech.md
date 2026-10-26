# Tech Stack

## Core Tools

- **Terraform** >= 1.0.0
- **AWS Provider** (hashicorp/aws) >= 5.0.0 at layer level, >= 4.31.0 in modules
- **Kubernetes Provider** (hashicorp/kubernetes) para recursos dentro de EKS
- **Helm Provider** (hashicorp/helm) para addons del clúster (ej. AWS Load Balancer Controller)
- **Backend**: S3 (config pasada vía `-backend-config` en la ejecución local)

## Conventions

- Provider alias: always use `aws.project` for the main provider
- Provider passes `default_tags` with corporate tags
- Profile variable allows local development via AWS CLI profiles
- Empty `profile` string falls back to default credential chain
- Los providers `kubernetes` y `helm` se autentican contra el clúster EKS usando
  los outputs del módulo EKS (endpoint, CA, token / exec auth)

## Commands

There are no build/test scripts in the repository. La IaC se despliega de forma
local con el AWS CLI profile correspondiente a cada ambiente:

```bash
# Initialize (backend config provided externally)
terraform init -backend-config=...

# Plan with environment-specific vars
terraform plan -var-file=../environment/{env}/{layer}/{env}.tfvars

# Apply
terraform apply -var-file=../environment/{env}/{layer}/{env}.tfvars
```
