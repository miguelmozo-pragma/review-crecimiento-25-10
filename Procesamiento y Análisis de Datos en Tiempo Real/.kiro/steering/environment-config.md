---
inclusion: manual
---

# Skill: Configurar Variables de Ambiente (tfvars)

Guía para crear y mantener archivos de variables por ambiente en `layers/environment/`.

## Estructura de Directorios

```
layers/environment/
├── dev/
│   ├── storage/dev.tfvars
│   ├── ingestion/dev.tfvars
│   ├── processing/dev.tfvars
│   └── consumption/dev.tfvars
├── qa/
│   └── ... (mismos layers)
└── prod/
    └── ... (mismos layers)
```

## Ruta del archivo

```
layers/environment/{env}/{layer}/{env}.tfvars
```

- `{env}`: dev, qa, prod
- `{layer}`: storage, ingestion, processing, consumption

## Plantilla Base

```hcl
###############################################
# RTDA - {Layer} - {Env}
# {Descripción breve del layer}
###############################################

project     = "rtda"
environment = "{env}"
region      = "us-west-2"
profile     = ""

# Variables específicas del layer
...

# Tags corporativos
common_tags = {
  Ambiente    = "{Ambiente}"
  Proyecto    = "RTDA"
  Descripcion = "{Descripción del layer} - {Env}"
  Nombre      = "rtda-{env}-{layer}"
  ManagedBy   = "terraform"
}
```

## Valores por Ambiente

### Variables fijas

| Variable      | dev              | qa               | prod             |
|---------------|------------------|------------------|------------------|
| project       | rtda             | rtda             | rtda             |
| environment   | dev              | qa               | prod             |
| region        | us-west-2        | us-west-2        | us-west-2        |
| profile       | ""               | ""               | ""               |

### Tags que cambian por ambiente

| Tag           | dev         | qa        | prod        |
|---------------|-------------|-----------|-------------|
| Ambiente      | Desarrollo  | Calidad   | Produccion  |

## Dimensionamiento por Ambiente

| Recurso                         | dev        | qa         | prod        |
|---------------------------------|------------|------------|-------------|
| Kinesis shards / mode           | on-demand  | on-demand  | provisioned |
| Firehose buffering (MB / s)     | 5 / 300    | 5 / 120    | 64 / 60     |
| Flink paralelismo (KPU)         | 1          | 2          | 4+          |
| Lambda memoria / timeout        | 256 / 30   | 512 / 60   | 1024 / 60   |
| S3 lifecycle (días a IA)        | 30         | 60         | 90          |

## Reglas

- **NUNCA** poner secretos en tfvars — usar SSM Parameter Store o Secrets Manager
- **Los valores de tags no deben contener comas** (varios servicios AWS las rechazan)
- Cada variable del layer debe estar presente en los 3 ambientes
- Los valores por defecto van en `variables.tf` del layer, NO en tfvars
- El profile vacío (`""`) usa el default credential chain (ejecución local)

## Checklist

- [ ] Archivo creado en `layers/environment/{env}/{layer}/{env}.tfvars`
- [ ] Header con nombre del layer y ambiente
- [ ] Variables fijas: project, environment, region, profile
- [ ] common_tags con los tags corporativos obligatorios (sin comas)
- [ ] Valores de Ambiente correctos (Desarrollo/Calidad/Produccion)
- [ ] Dimensionamiento apropiado por ambiente
- [ ] Creado para los 3 ambientes (dev, qa, prod)
- [ ] Sin secretos en el archivo
