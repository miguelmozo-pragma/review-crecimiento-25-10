---
inclusion: auto
fileMatchPattern: "modules/**/*.tf"
---

# Convención de Nomenclatura de Recursos AWS

## Patrón General

```
{carga}-{entorno}-{componente}-{funcionalidad}
```

| Segmento      | Descripción                                    | Valores                                                         |
|---------------|------------------------------------------------|-----------------------------------------------------------------|
| carga         | Código del proyecto                            | `cb`                                                            |
| entorno       | Ambiente de despliegue                         | `dev`, `qa`, `prod`                                             |
| componente    | Tipo de servicio/recurso AWS                   | `vpc`, `eks`, `ecr`, `alb`, `cf`, `acm`, `aurora`, `elasticache`, `s3`, `kms`, `dms`, `datasync`, `vpn`, `sg`, `secret` |
| funcionalidad | Aplicación o funcionalidad de negocio          | `frontend`, `estado-cuentas`, `creditos`, `recaudo`, `inversiones`, `administrativo` |

## Implementación en Módulos

Cada módulo define la nomenclatura en `locals.tf`:

```hcl
locals {
  base_name     = "cb-${var.environment}"
  resource_name = "${local.base_name}-{componente}-${var.nombre_variable}"
}
```

### Regla fundamental

El segmento `{componente}` **siempre** se incluye como literal en `locals.tf` del módulo. **Nunca** se pasa como variable desde el layer. Esto garantiza consistencia automática.

### Ejemplo — Módulo Aurora

```hcl
# modules/aurora/locals.tf
locals {
  base_name     = "cb-${var.environment}"
  cluster_name  = "${local.base_name}-aurora-${var.cluster_name}"
  writer_name   = "${local.base_name}-aurora-${var.cluster_name}-writer"
  reader_name   = "${local.base_name}-aurora-${var.cluster_name}-reader"
}
```

### Ejemplo — Módulo KMS

```hcl
# modules/kms/locals.tf
locals {
  base_name  = "cb-${var.environment}"
  key_name   = "${local.base_name}-kms-${var.key_name}"
  alias_name = "alias/${local.base_name}-kms-${var.key_name}"
}
```

### Ejemplo — Módulo EKS

```hcl
# modules/eks/locals.tf
locals {
  base_name    = "cb-${var.environment}"
  cluster_name = "${local.base_name}-eks-${var.cluster_name}"
}
```

## Nombres Especiales

### SSM Parameter Store

Patrón jerárquico con `/`:

```
/cb/{environment}/{layer}/{recurso-descripcion}
```

Ejemplos:
- `/cb/dev/networking/vpc-id`
- `/cb/qa/security/kms-aurora-arn`
- `/cb/prod/data/aurora-endpoint`

### CloudWatch Log Groups

Patrón con `/` según el servicio:

```
/cb/{environment}/{servicio}/{funcionalidad}
```

Ejemplos:
- `/cb/dev/eks/cluster`
- `/cb/qa/eks/creditos`
- `/cb/prod/aurora/cluster`

### Pipelines de despliegue de código (aplicaciones)

> La IaC se despliega localmente; estos pipelines son solo para el despliegue del
> código de las aplicaciones (build de imagen → push a ECR → deploy al módulo en EKS).

```
cb-{env}-pipeline-{modulo}
```

Ejemplos:
- `cb-dev-pipeline-frontend`
- `cb-prod-pipeline-estado-cuentas`
- `cb-qa-pipeline-creditos`

### S3 State Bucket

```
bgsas-{env}-iac-terraform-state-core-bancario
```

## Tags Name

El tag `Name` de cada recurso debe coincidir con el nombre lógico del recurso:

```hcl
tags = merge(
  { Name = local.resource_name },
  var.additional_tags
)
```

## Reglas de Validación

- Solo minúsculas y guiones (`-`) en nombres de recursos
- Sin caracteres especiales excepto `/` en SSM y CloudWatch
- Sin underscores (`_`) en nombres de recursos AWS (excepto donde AWS lo requiera: RDS parameter groups, Lambda)
- Máximo 63 caracteres para nombres de recursos (límite S3 / EKS)
- El proyecto siempre es `cb` (no variable en nomenclatura)
