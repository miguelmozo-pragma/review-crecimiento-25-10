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
| carga         | Código del proyecto                            | `rtda`                                                          |
| entorno       | Ambiente de despliegue                         | `dev`, `qa`, `prod`                                             |
| componente    | Tipo de servicio/recurso AWS                   | `kinesis`, `firehose`, `s3`, `flink`, `lambda`, `sns`, `kms`, `fraud`, `lakeformation`, `glue`, `sg` |
| funcionalidad | Aplicación o funcionalidad de negocio          | `ingesta`, `raw`, `datalake`, `procesamiento`, `fraude`, `notif`, `evento-fraude` |

## Implementación en Módulos

Cada módulo define la nomenclatura en `locals.tf`:

```hcl
locals {
  base_name     = "rtda-${var.environment}"
  resource_name = "${local.base_name}-{componente}-${var.nombre_variable}"
}
```

### Regla fundamental

El segmento `{componente}` **siempre** se incluye como literal en `locals.tf` del módulo. **Nunca** se pasa como variable desde el layer. Esto garantiza consistencia automática.

### Ejemplo — Módulo Kinesis

```hcl
# modules/kinesis/locals.tf
locals {
  base_name   = "rtda-${var.environment}"
  stream_name = "${local.base_name}-kinesis-${var.stream_name}"   # rtda-prod-kinesis-ingesta
}
```

### Ejemplo — Módulo Firehose

```hcl
# modules/firehose/locals.tf
locals {
  base_name      = "rtda-${var.environment}"
  delivery_name  = "${local.base_name}-firehose-${var.name}"       # rtda-prod-firehose-raw
}
```

### Ejemplo — Módulo Lambda

```hcl
# modules/lambda/locals.tf
locals {
  base_name     = "rtda-${var.environment}"
  function_name = "${local.base_name}-lambda-${var.function_name}" # rtda-prod-lambda-evento-fraude
}
```

## Nombres Especiales

### SSM Parameter Store

Patrón jerárquico con `/`:

```
/rtda/{environment}/{layer}/{recurso-descripcion}
```

Ejemplos:
- `/rtda/prod/ingestion/kinesis-stream-arn`
- `/rtda/prod/storage/datalake-bucket`
- `/rtda/prod/processing/flink-app-arn`

### CloudWatch Log Groups

```
/rtda/{environment}/{servicio}/{funcionalidad}
```

Ejemplos:
- `/rtda/prod/lambda/evento-fraude`
- `/rtda/prod/flink/procesamiento`
- `/rtda/prod/firehose/raw`

### Pipelines de despliegue de código (Lambda)

> La IaC se despliega localmente; estos pipelines son solo para el despliegue del
> código de las funciones Lambda (build → publicar nueva versión).

```
rtda-{env}-pipeline-{funcionalidad}
```

### S3 State Bucket

```
bgsas-{env}-iac-terraform-state-rtda
```

### S3 Data Lake / Raw buckets

```
rtda-{env}-s3-{funcionalidad}
```

Ejemplos: `rtda-prod-s3-raw`, `rtda-prod-s3-datalake`.

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
- Sin underscores (`_`) en nombres de recursos AWS (excepto donde AWS lo requiera: Lambda, Glue, Firehose)
- Máximo 63 caracteres para nombres de recursos (límite S3)
- El proyecto siempre es `rtda` (no variable en nomenclatura)
