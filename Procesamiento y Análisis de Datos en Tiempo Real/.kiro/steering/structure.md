# Project Structure

## Layout

```
.
├── layers/                        # Infrastructure layers (each independently deployable)
│   ├── ingestion/                 # Kinesis Data Stream + Firehose + S3 raw + KMS
│   ├── storage/                   # S3 Data Lake + Lake Formation (catalogs, databases, permissions)
│   ├── processing/                # Managed Service for Apache Flink + Fraud Detector
│   ├── consumption/               # Lambda (evento de fraude) + SNS topic
│   └── environment/               # Per-environment variable files
│       ├── dev/{layer}/dev.tfvars
│       ├── qa/{layer}/qa.tfvars
│       └── prod/{layer}/prod.tfvars
├── modules/                       # Reusable Terraform modules
│   ├── kinesis/                   # Kinesis Data Stream + KMS
│   ├── firehose/                  # Kinesis Data Firehose delivery stream -> S3
│   ├── s3/                        # Buckets S3 (raw / data lake) + KMS
│   ├── lakeformation/             # Lake Formation catalogs, databases, permissions
│   ├── flink/                     # Managed Service for Apache Flink application
│   ├── fraud-detector/            # AWS Fraud Detector (detector, models, rules)
│   ├── lambda/                    # Lambda function + IAM role + pipeline + CloudWatch
│   └── sns/                       # SNS topic + subscriptions + KMS
└── scripts/                       # Utility scripts (planned)
```

## Layer File Convention

Each layer contains a standard set of files:

| File          | Purpose                                      |
|---------------|----------------------------------------------|
| main.tf       | Resource definitions and module calls        |
| providers.tf  | Provider config, terraform block, backend    |
| variables.tf  | Input variable declarations                  |
| data.tf       | Data sources                                 |
| outputs.tf    | Output values                                |

## Etapas del pipeline (orden de despliegue)

```
storage → ingestion → processing → consumption
```

- **storage**: crea el Data Lake (S3 + Lake Formation) del que dependen las demás etapas.
- **ingestion**: Kinesis + Firehose entregando a los buckets de storage.
- **processing**: Flink consume del stream de ingestion e invoca Fraud Detector.
- **consumption**: Lambda + SNS reaccionan a los resultados del procesamiento.

## Naming Convention

Todos los recursos AWS deben seguir esta convención de nomenclatura:

```
{carga}-{entorno}-{componente}-{funcionalidad}
```

| Segmento       | Descripción                                                          | Ejemplos                          |
|----------------|----------------------------------------------------------------------|-----------------------------------|
| carga          | Nombre de la carga de trabajo / proyecto                             | rtda                              |
| entorno        | Ambiente de despliegue                                               | dev, qa, prod                     |
| componente     | Tipo de servicio/recurso AWS                                         | kinesis, firehose, s3, flink, lambda, sns, kms, fraud, lakeformation |
| funcionalidad  | Aplicación, servicio o funcionalidad de negocio                      | ingesta, raw, datalake, procesamiento, fraude, notif |

### Implementación en módulos

Cada módulo define en `locals.tf`:

```hcl
locals {
  base_name     = "rtda-${var.environment}"
  resource_name = "${local.base_name}-{componente}-${var.nombre_variable}"
}
```

El segmento `{componente}` **siempre se incluye en el local del módulo**, no se pasa como variable.

### Otros nombres

- **Modules sourced as**: `../../modules/{module-name}`

## Environment Variable Files

Environment-specific configuration lives in `layers/environment/{env}/{layer}/{env}.tfvars`. Each file defines:
- Project/environment identifiers
- Sizing por ambiente (shards de Kinesis, buffering de Firehose, paralelismo de Flink, memoria/timeout de Lambda)
- Retention settings (Kinesis retention, S3 lifecycle, log retention)
- Feature flags
- Corporate tags (`common_tags`)
