# Tech Stack

## Core Tools

- **Terraform** >= 1.0.0
- **AWS Provider** (hashicorp/aws) >= 5.0.0 at layer level, >= 4.31.0 in modules
- **Backend**: S3 (config pasada vía `-backend-config` en la ejecución local)

## Arquitectura (serverless streaming / analytics)

Pipeline de procesamiento y análisis de datos en tiempo real en tres etapas:

1. **Ingesta**: Kinesis Data Stream → Kinesis Data Firehose → S3 (raw).
2. **Procesamiento**: Amazon Managed Service for Apache Flink → invoca AWS Fraud Detector.
3. **Consumo**: Lambda (genera evento ante fraude) + SNS (notificación). Catalogación y gobierno con Lake Formation sobre el Data Lake en S3.

No hay cómputo basado en contenedores (EKS) ni bases de datos relacionales; es una arquitectura gestionada/serverless.

## Conventions

- Provider alias: always use `aws.project` for the main provider
- Provider passes `default_tags` with corporate tags
- Profile variable allows local development via AWS CLI profiles
- Empty `profile` string falls back to default credential chain
- No se usan los providers `kubernetes`/`helm` (no hay EKS en este proyecto)

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
