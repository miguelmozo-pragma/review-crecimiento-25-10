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

### Si el layer gestiona recursos de Kubernetes (platform / workload)

Agregar los providers `kubernetes` y `helm`, autenticados con los outputs del módulo EKS:

```hcl
provider "kubernetes" {
  host                   = var.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(var.eks_cluster_ca)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = var.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(var.eks_cluster_ca)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
    }
  }
}
```

Los valores de endpoint, CA y nombre del clúster se leen del layer `platform` vía SSM o remote state.

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

### Llamadas a módulos

```hcl
# ==========================================================================
# N. Descripción del módulo
# ==========================================================================
module "{nombre_descriptivo}" {
  source = "../../modules/{nombre-modulo}"
  providers = {
    aws.project = aws.project
  }

  # Variables comunes
  project     = var.project
  environment = var.environment
  aws_region  = var.region

  # Variables específicas del módulo
  ...

  # Tags
  additional_tags = var.common_tags
}
```

### Reglas de main.tf

- Numerar secciones de módulos (1, 2, 3...)
- `source` siempre relativo: `../../modules/{nombre-modulo}`
- Pasar providers explícitamente: `aws.project = aws.project`
- Variables comunes primero, luego específicas, luego tags
- Para recursos condicionales usar `count` con feature flags (ej. `create_read_replica`, `create_vpn`)
- No hardcodear valores — todo se parametriza via variables
- El módulo genera nombres automáticamente (`cb-{env}-{componente}-{funcionalidad}`)

## variables.tf

### Variables obligatorias (siempre presentes)

```hcl
###############################################
# Variables generales
###############################################

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

###############################################
# Variables Tags
###############################################

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

### Convenciones

- Descripciones en español en el layer
- Agrupar variables con separadores `###############################################`
- Feature flags como `create_xxx` (bool, default = false) para recursos condicionales
- Variables de dimensionamiento por ambiente (tamaño de instancias, # de pods, # de AZs) pasadas desde tfvars

## data.tf

```hcl
###############################################
# Data Sources
###############################################

data "aws_caller_identity" "current" {
  provider = aws.project
}

data "aws_region" "current" {
  provider = aws.project
}
```

Agregar data sources adicionales según necesidades:
- `aws_ssm_parameter` para obtener outputs de otros layers (VPC IDs, subnet IDs, ARNs de KMS, endpoint de EKS, etc.)
- `terraform_remote_state` como alternativa (menos preferido)

## outputs.tf

```hcl
###############################################
# Outputs
###############################################

output "{nombre_output}" {
  description = "Descripción en español"
  value       = module.{nombre}.{output_del_modulo}
}
```

### Convenciones de outputs

- Exponer IDs, ARNs y nombres de recursos principales
- Descripciones en español
- Usar mapas cuando se exponen recursos creados con `for_each`
- Los outputs de un layer se consumen por otros layers vía SSM o remote state

## Comunicación entre Layers

### Patrón preferido: SSM Parameter Store

El layer productor publica en SSM:

```hcl
resource "aws_ssm_parameter" "vpc_id" {
  provider = aws.project
  name     = "/cb/${var.environment}/networking/vpc-id"
  type     = "String"
  value    = module.vpc.vpc_id
  tags     = merge({ Name = "/cb/${var.environment}/networking/vpc-id" }, var.common_tags)
}
```

El layer consumidor lee de SSM en `data.tf`:

```hcl
data "aws_ssm_parameter" "vpc_id" {
  provider = aws.project
  name     = "/cb/${var.environment}/networking/vpc-id"
}
```

### Convención de nombres SSM

```
/cb/{environment}/{layer}/{recurso-descripcion}
```

## Orden de Despliegue entre Layers

```
networking → security → platform (EKS) → data → workload → migration
```

Cada layer solo depende de layers anteriores en la cadena.

## Ejecución Local

```bash
# Desde el directorio del layer
cd layers/{nombre-layer}

# Init con backend config
terraform init \
  -backend-config="bucket=bgsas-{env}-iac-terraform-state-core-bancario" \
  -backend-config="key={nombre-layer}/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -backend-config="profile=core_bancario_{env}" \
  -input=false -reconfigure

# Plan
terraform plan -var-file=../environment/{env}/{nombre-layer}/{env}.tfvars -input=false

# Apply
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
- [ ] Outputs documentados con descripción en español
