---
inclusion: manual
---

# Skill: Configurar Variables de Ambiente (tfvars)

Guía para crear y mantener archivos de variables por ambiente en `layers/environment/`.

## Estructura de Directorios

```
layers/environment/
├── dev/
│   ├── networking/dev.tfvars
│   ├── security/dev.tfvars
│   ├── platform/dev.tfvars
│   ├── data/dev.tfvars
│   ├── workload/dev.tfvars
│   └── migration/dev.tfvars
├── qa/
│   ├── networking/qa.tfvars
│   ├── security/qa.tfvars
│   ├── platform/qa.tfvars
│   ├── data/qa.tfvars
│   ├── workload/qa.tfvars
│   └── migration/qa.tfvars
└── prod/
    ├── networking/prod.tfvars
    ├── security/prod.tfvars
    ├── platform/prod.tfvars
    ├── data/prod.tfvars
    ├── workload/prod.tfvars
    └── migration/prod.tfvars
```

## Ruta del archivo

```
layers/environment/{env}/{layer}/{env}.tfvars
```

- `{env}`: dev, qa, prod
- `{layer}`: nombre del layer (networking, security, platform, data, workload, migration)

## Plantilla Base

```hcl
###############################################
# AGAT - {Layer} - {Env}
# {Descripción breve del layer}
###############################################

project     = "agat"
environment = "{env}"
region      = "us-west-2"
profile     = "agat_{env}"

# Variables específicas del layer
...

# Tags corporativos
common_tags = {
  Ambiente    = "{Ambiente}"
  Proyecto    = "AGAT"
  Descripcion = "{Descripción del layer} - {Env}"
  Nombre      = "agat-{env}-{layer}"
  ManagedBy   = "terraform"
}
```

## Valores por Ambiente

### Variables fijas

| Variable      | dev                   | qa                    | prod                  |
|---------------|-----------------------|-----------------------|-----------------------|
| project       | agat                  | agat                  | agat                  |
| environment   | dev                   | qa                    | prod                  |
| region        | us-west-2             | us-west-2             | us-west-2             |
| profile       | agat_dev     | agat_qa      | agat_prod    |

### Tags que cambian por ambiente

| Tag           | dev         | qa        | prod        |
|---------------|-------------|-----------|-------------|
| Ambiente      | Desarrollo  | Calidad   | Produccion  |

### Tags fijos (mismos en todos los ambientes)

| Tag              | Valor                                  |
|------------------|----------------------------------------|
| Proyecto         | AGAT                          |
| ManagedBy        | terraform                              |

## Dimensionamiento por Ambiente

Los valores de dimensionamiento se pasan por tfvars y cambian según el ambiente:

| Recurso                     | dev                      | qa                       | prod                     |
|-----------------------------|--------------------------|--------------------------|--------------------------|
| AZs                         | 1                        | 3                        | 3                        |
| Pods por deployment         | 1                        | 3                        | 3                        |
| Memoria / CPU por pod       | 512 MB / 256 mCPU        | 512 MB / 256 mCPU        | 1024 MB / 512 mCPU       |
| Aurora                      | 1 writer (pequeña)       | writer + reader (mediana)| writer + reader (grande) |
| ElastiCache Redis           | pequeña                  | mediana                  | grande                   |
| DMS replication instance    | pequeña                  | mediana                  | grande                   |

Feature flags asociados (ejemplos): `create_read_replica` (false en dev, true en qa/prod), número de AZs via lista de subnets en tfvars.

## Pasos para Agregar un Nuevo Layer

1. Crear el directorio: `layers/environment/{env}/{layer}/`
2. Crear el archivo: `{env}.tfvars`
3. Incluir las variables obligatorias (project, environment, region, profile)
4. Incluir `common_tags` con todos los tags corporativos
5. Agregar variables específicas del layer (incluido el dimensionamiento)
6. Repetir para los 3 ambientes (dev, qa, prod)

## Reglas

- **NUNCA** poner secretos en tfvars — usar SSM Parameter Store o Secrets Manager
- Cada variable del layer debe estar presente en los 3 ambientes
- Los valores por defecto van en `variables.tf` del layer, NO en tfvars
- El profile en tfvars corresponde al AWS CLI profile usado para el despliegue local de cada ambiente
- Mantener los 3 archivos sincronizados: si se agrega una variable, agregarla en los 3

## Uso en Comandos

```bash
# Plan con tfvars de dev
terraform plan -var-file=../environment/dev/{layer}/dev.tfvars

# Apply con tfvars de qa
terraform apply -var-file=../environment/qa/{layer}/qa.tfvars
```

## Checklist

- [ ] Archivo creado en `layers/environment/{env}/{layer}/{env}.tfvars`
- [ ] Header con nombre del layer y ambiente
- [ ] Variables fijas: project, environment, region, profile
- [ ] common_tags con los tags corporativos obligatorios
- [ ] Valores de Ambiente correctos (Desarrollo/Calidad/Produccion)
- [ ] Feature flags y dimensionamiento configurados apropiadamente por ambiente
- [ ] Creado para los 3 ambientes (dev, qa, prod)
- [ ] Sin secretos en el archivo
