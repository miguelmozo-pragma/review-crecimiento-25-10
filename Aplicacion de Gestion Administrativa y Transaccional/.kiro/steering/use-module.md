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

## Estructura del Layer

```
layers/{layer}/
├── main.tf          # Llamadas a módulos
├── variables.tf     # Variables del layer (pasadas a módulos)
├── outputs.tf       # Outputs expuestos del layer
├── data.tf          # Data sources (caller identity, region, etc.)
├── providers.tf     # Provider, terraform block, backend s3
```

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
- Tags se pasan como `additional_tags = var.common_tags` (el módulo los propaga a los recursos)
- **No pasar el componente en el nombre del recurso** — el módulo lo agrega automáticamente en locals.tf según la convención `agat-{env}-{componente}-{funcionalidad}`
- No hardcodear valores en main.tf del layer — todo se parametriza via variables

## Convenciones para providers.tf del Layer

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
    bucket  = "bgsas-{env}-iac-terraform-state-gestion-admin"
    key     = "{nombre_del_layer}/terraform.tfstate"
    region  = "us-west-2"
    profile = "agat_{env}"
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

## Convenciones para outputs.tf del Layer

```hcl
output "{nombre_output}" {
  description = "Descripción en español"
  value       = module.{nombre}.{output_del_modulo}
}
```

## Archivos tfvars por Ambiente

Ruta: `layers/environment/{env}/{layer}/{env}.tfvars`

### Estructura estándar de un tfvars
```hcl
###############################################
# AGAT - {Layer} - {Env}
# Descripción breve
###############################################

project     = "agat"
environment = "{env}"
region      = "us-west-2"
profile     = "agat_{env}"

# Variables específicas del módulo
...

# Tags corporativos
common_tags = {
  Ambiente         = "{Ambiente}"
  Proyecto         = "AGAT"
  Descripcion      = "{descripción}"
  Nombre           = "agat-{env}-{recurso}"
  Area_Responsable = "Jef_Soluciones_Digitales"
  ManagedBy        = "terraform"
  Repositorio      = "AGAT_Infraestructura_IaC"
}
```

### Valores de Ambiente por entorno
| Campo    | dev           | qa             | prod         |
|----------|---------------|----------------|--------------|
| Ambiente | Desarrollo    | Calidad        | Produccion   |

## Checklist Final

- [ ] `source` apunta correctamente a `../../modules/{modulo}`
- [ ] Providers pasados con `aws.project = aws.project`
- [ ] Variables del layer coinciden con las del módulo (usar `aws_region` para la región)
- [ ] Tags pasados como `additional_tags = var.common_tags`
- [ ] Sin valores hardcodeados en main.tf — todo parametrizado via variables
- [ ] Outputs del layer exponen los outputs del módulo
- [ ] tfvars creados para los 3 ambientes (dev, qa, prod)
- [ ] `common_tags` incluye todos los tags corporativos obligatorios
- [ ] Header de main.tf y providers.tf documenta los recursos del layer
- [ ] Naming: el módulo genera nombres con patrón `agat-{env}-{componente}-{funcionalidad}` automáticamente
