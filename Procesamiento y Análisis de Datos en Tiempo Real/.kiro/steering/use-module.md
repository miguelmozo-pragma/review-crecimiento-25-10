---
inclusion: manual
---

# Skill: Usar un Módulo en un Layer

Guía para integrar un módulo existente de `modules/` dentro de un layer de infraestructura.

## Pasos

1. Identificar el layer destino en `layers/{layer}/`
2. Agregar el bloque `module` en `main.tf` del layer
3. Declarar las variables necesarias en `variables.tf` del layer
4. Exponer outputs relevantes en `outputs.tf` del layer
5. Configurar los valores en los archivos tfvars de cada ambiente

## Convenciones para main.tf del Layer

### Header del archivo
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

### Bloque module
```hcl
# ==========================================================================
# N. Descripción del módulo
# ==========================================================================
module "{nombre}" {
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

### Reglas
- `source` siempre relativo: `../../modules/{nombre-modulo}`
- Pasar providers explícitamente: `aws.project = aws.project`
- Numerar secciones de módulos (1, 2, 3...)
- Variables comunes (project, environment, aws_region) primero, luego específicas
- Tags se pasan como `additional_tags = var.common_tags`
- **No pasar el componente en el nombre del recurso** — el módulo lo agrega automáticamente en locals.tf según la convención `rtda-{env}-{componente}-{funcionalidad}`
- No hardcodear valores en main.tf del layer — todo se parametriza via variables

## Convenciones para providers.tf del Layer

```hcl
###############################################
# Gobierno: {NombreLayer}
# Ambiente: ALL
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
    bucket  = "bgsas-{env}-iac-terraform-state-rtda"
    key     = "{nombre_del_layer}/terraform.tfstate"
    region  = "us-west-2"
  }
}
```

## Convenciones para variables.tf del Layer

- Incluir siempre:
  - `project` (string)
  - `environment` (string) con validation `contains(["dev", "qa", "prod"], ...)`
  - `region` (string)
  - `profile` (string, default = "")
  - `common_tags` (map(string)) con default del esqueleto de tags corporativos
- Variables específicas del módulo se replican en el layer para pasarlas
- Descripciones en español en el layer

## Comunicación entre Layers (SSM)

El layer productor publica outputs en SSM:

```hcl
resource "aws_ssm_parameter" "kinesis_stream_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-stream-arn"
  type     = "String"
  value    = module.kinesis.stream_arn
  tags     = merge({ Name = "/rtda/${var.environment}/ingestion/kinesis-stream-arn" }, var.common_tags)
}
```

El consumidor lee de SSM en `data.tf`:

```hcl
data "aws_ssm_parameter" "kinesis_stream_arn" {
  provider = aws.project
  name     = "/rtda/${var.environment}/ingestion/kinesis-stream-arn"
}
```

## Checklist Final

- [ ] `source` apunta correctamente a `../../modules/{modulo}`
- [ ] Providers pasados con `aws.project = aws.project`
- [ ] Variables del layer coinciden con las del módulo (usar `aws_region` para la región)
- [ ] Tags pasados como `additional_tags = var.common_tags`
- [ ] Sin valores hardcodeados en main.tf — todo parametrizado via variables
- [ ] Outputs del layer exponen los outputs del módulo (y se publican en SSM)
- [ ] tfvars creados para los 3 ambientes (dev, qa, prod)
- [ ] `common_tags` incluye todos los tags corporativos obligatorios (sin comas)
- [ ] Naming: el módulo genera nombres con patrón `rtda-{env}-{componente}-{funcionalidad}` automáticamente
