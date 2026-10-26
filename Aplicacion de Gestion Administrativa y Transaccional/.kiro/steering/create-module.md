---
inclusion: manual
---

# Skill: Crear Nuevo Módulo Terraform

Guía para generar un nuevo módulo reutilizable en `modules/`.

## Pasos

1. Crear el directorio `modules/{nombre-modulo}/`
2. Generar los archivos estándar del módulo (ver estructura abajo)
3. Crear los archivos tfvars correspondientes en `layers/environment/{dev,qa,prod}/{layer}/`

## Estructura de Archivos del Módulo

```
modules/{nombre-modulo}/
├── main.tf          # Recursos del módulo
├── variables.tf     # Variables de entrada
├── outputs.tf       # Valores de salida
├── locals.tf        # Nombres y valores computados
├── providers.tf     # Declaración de providers requeridos
```

## Convenciones Obligatorias

### providers.tf
- Declarar `configuration_aliases = [aws.project]` en el bloque `required_providers`
- NO declarar backend (solo se declara en el layer)
- Versión del provider AWS: `>= 5.0.0`
- Para módulos que crean recursos Kubernetes/Helm, declarar también los
  `configuration_aliases` de `kubernetes` y/o `helm`

```hcl
terraform {
  required_providers {
    aws = {
      configuration_aliases = [aws.project]
      source                = "hashicorp/aws"
      version               = ">= 5.0.0"
    }
  }
}
```

### variables.tf
- Incluir siempre las variables comunes al inicio:
  - `project` (string) — Nombre del proyecto
  - `environment` (string) — Ambiente (dev, qa, prod)
  - `region` (string) — Región AWS
- Incluir `common_tags` (map(string)) para tags corporativos
- Incluir `additional_tags` (map(string), default = {}) para tags extra
- Usar validaciones donde aplique (regex, contains, can)
- Agrupar variables con separadores `###########################################`
- Descripciones en inglés dentro del módulo

### locals.tf
- Definir `base_name = "agat-${var.environment}"`
- Construir todos los nombres de recursos como `"${local.base_name}-{componente}-${var.nombre_variable}"`
  - El segmento `{componente}` corresponde al tipo de servicio AWS del módulo (vpc, eks, ecr, aurora, elasticache, s3, kms, dms, etc.)
  - Se incluye directamente en el local, NO se pasa como variable
  - Ejemplo para Aurora: `cluster_name = "${local.base_name}-aurora-${var.cluster_name}"` → `agat-dev-aurora-core`
  - Ejemplo para EKS: `cluster_name = "${local.base_name}-eks-${var.cluster_name}"` → `agat-dev-eks-core`
  - Ejemplo para S3: `bucket_name = "${local.base_name}-s3-${var.bucket_name}"` → `agat-dev-s3-objetos`
- Centralizar lógica de nombres complejos (maps con for expressions)

### main.tf
- Usar `provider = aws.project` en TODOS los recursos AWS
- Todos los recursos deben incluir bloque `tags` con merge:
  ```hcl
  tags = merge(
    { Name = local.nombre_recurso },
    var.additional_tags
  )
  ```
- Agrupar recursos con separadores y headers descriptivos
- Usar `checkov:skip=CKV_XXX` con comentario cuando se acepte un riesgo

### outputs.tf
- Exponer IDs y ARNs de los recursos principales
- Incluir `description` en cada output
- Preferir maps cuando se exponen recursos creados con `for_each`

## Ejemplo de Validaciones en Variables

```hcl
variable "environment" {
  type        = string
  description = "Environment where resources will be deployed"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Must be dev, qa, or prod."
  }
}
```

## Checklist Final

- [ ] Todos los recursos AWS usan `provider = aws.project`
- [ ] Naming sigue el patrón `agat-{environment}-{componente}-{funcionalidad}` (componente = tipo AWS del módulo)
- [ ] El segmento `{componente}` está en locals.tf, no se pasa como variable
- [ ] Tags corporativos propagados via `common_tags` o `additional_tags`
- [ ] Variables con type, description y validaciones
- [ ] Outputs con description
- [ ] No hay backend declarado en el módulo
- [ ] `configuration_aliases = [aws.project]` presente en providers.tf
