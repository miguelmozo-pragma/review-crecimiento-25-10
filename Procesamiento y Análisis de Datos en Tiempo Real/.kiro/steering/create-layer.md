---
inclusion: manual
---

# Skill: Crear Nuevo Layer de Infraestructura

Guía para crear un nuevo layer desplegable de forma independiente en `layers/`.

## Pasos

1. Crear el directorio `layers/{nombre-layer}/`
2. Generar los 5 archivos estándar del layer
3. Crear los archivos tfvars para los 3 ambientes en `layers/environment/{dev,qa,prod}/{nombre-layer}/`

## Estructura de Archivos del Layer

```
layers/{nombre-layer}/
├── main.tf          # Llamadas a módulos y recursos
├── providers.tf     # Provider config, terraform block, backend s3
├── variables.tf     # Variables de entrada del layer
├── data.tf          # Data sources (caller identity, region, SSM, etc.)
├── outputs.tf       # Outputs expuestos del layer
```

## providers.tf

```hcl
###############################################
# Gobierno: {NombreLayer}
# Ambiente: ALL
#
# Recursos:
#   - (lista de recursos)
###############################################

provider "aws" {
  alias   = "project"
  region  = var.region
  profile = var.profile != "" ? var.profile : null
  default_tags {
    tags = var.common_tags
  }
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
  backend "s3" {
    region = "us-west-2"
  }
}
```

### Reglas del backend

- Declarar `backend "s3"` solo con `region = "us-west-2"`
- Los demás parámetros (bucket, key, profile) se pasan vía `-backend-config` en la ejecución local
- El key del state sigue el patrón: `{nombre-layer}/terraform.tfstate`

## main.tf

### Header obligatorio

```hcl
###############################################
# Gobierno: {NombreLayer}
# Ambiente: ALL
#
# Recursos:
#   - {Recurso1} ({cantidad})
#   - {Recurso2} ({cantidad})
###############################################
```

### Reglas de main.tf

- Numerar secciones de módulos (1, 2, 3...)
- `source` siempre relativo: `../../modules/{nombre-modulo}`
- Pasar providers explícitamente: `aws.project = aws.project`
- Variables comunes primero, luego específicas, luego tags
- Para recursos condicionales usar `count`/`for_each` con feature flags
- No hardcodear valores — todo se parametriza via variables
- El módulo genera nombres automáticamente (`rtda-{env}-{componente}-{funcionalidad}`)

## variables.tf

### Variables obligatorias (siempre presentes)

```hcl
variable "project" {
  type        = string
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  description = "Ambiente de despliegue"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "El ambiente debe ser 'dev', 'qa' o 'prod'."
  }
}

variable "region" {
  type        = string
  description = "Región AWS de despliegue"
}

variable "profile" {
  type        = string
  default     = ""
  description = "AWS CLI profile (vacío usa default credential chain)"
}

variable "common_tags" {
  description = "Tags corporativos obligatorios para todos los recursos"
  type        = map(string)
  default = {
    Ambiente    = ""
    Proyecto    = ""
    Descripcion = ""
  }
}
```

## data.tf

```hcl
data "aws_caller_identity" "current" {
  provider = aws.project
}

data "aws_region" "current" {
  provider = aws.project
}
```

Agregar data sources según necesidades:
- `aws_ssm_parameter` para obtener outputs de otros layers (ARN del Kinesis stream, bucket del data lake, etc.)

## outputs.tf

```hcl
output "{nombre_output}" {
  description = "Descripción en español"
  value       = module.{nombre}.{output_del_modulo}
}
```

## Comunicación entre Layers

Patrón preferido: **SSM Parameter Store**, con nombres `/rtda/{environment}/{layer}/{recurso-descripcion}`.

## Orden de Despliegue entre Layers

```
storage → ingestion → processing → consumption
```

- **storage**: Data Lake (S3 + Lake Formation). Base de las demás etapas.
- **ingestion**: Kinesis + Firehose → entrega a los buckets de storage.
- **processing**: Flink consume del stream e invoca Fraud Detector.
- **consumption**: Lambda + SNS reaccionan a los resultados.

Cada layer solo depende de layers anteriores en la cadena.

## Ejecución Local

```bash
cd layers/{nombre-layer}

terraform init \
  -backend-config="bucket=bgsas-{env}-iac-terraform-state-rtda" \
  -backend-config="key={nombre-layer}/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -input=false -reconfigure

terraform plan  -var-file=../environment/{env}/{nombre-layer}/{env}.tfvars -input=false
terraform apply -var-file=../environment/{env}/{nombre-layer}/{env}.tfvars -input=false
```

## Checklist Final

- [ ] 5 archivos creados: main.tf, providers.tf, variables.tf, data.tf, outputs.tf
- [ ] Header de gobierno en main.tf y providers.tf
- [ ] Backend declarado solo con `region = "us-west-2"`
- [ ] Provider alias `aws.project` con `default_tags`
- [ ] Variables obligatorias (project, environment, region, profile, common_tags)
- [ ] tfvars creados para dev, qa, prod en `layers/environment/{env}/{layer}/`
- [ ] Módulos pasados con `aws.project = aws.project`
- [ ] Sin valores hardcodeados — todo parametrizado
- [ ] Outputs documentados con descripción en español y publicados en SSM
