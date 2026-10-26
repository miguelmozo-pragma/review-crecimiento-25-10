# Project Structure

## Layout

```
.
├── layers/                        # Infrastructure layers (each independently deployable)
│   ├── networking/                # VPC, subnets privadas, route tables
│   ├── workload/                  # Cluster EKS + addons (ALB Controller)
│   ├── data/                      # Aurora PostgreSQL
│   ├── apps/                      # Recursos Kubernetes de los módulos (deployments, services, SA, ingress) + pipelines
│   └── environment/               # Per-environment variable files
│       ├── dev/{layer}/dev.tfvars
│       ├── qa/{layer}/qa.tfvars
│       └── prod/{layer}/prod.tfvars
├── modules/                       # Reusable Terraform modules
│   ├── vpc-module/                # VPC module (subnets, routing, VPC endpoints)
│   ├── eks/                       # Cluster EKS y node groups + addons
│   ├── microservice/              # ECR + IRSA + SA + Deployment/Service/Ingress + pipeline CI/CD
│   └── aurora/                    # Aurora PostgreSQL (writer + reader)
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

## Naming Convention

Todos los recursos AWS deben seguir esta convención de nomenclatura:

```
{carga}-{entorno}-{componente}-{funcionalidad}
```

| Segmento       | Descripción                                                          | Ejemplos                          |
|----------------|----------------------------------------------------------------------|-----------------------------------|
| carga          | Nombre de la carga de trabajo / proyecto                             | agat                              |
| entorno        | Ambiente de despliegue                                               | dev, qa, prod                     |
| componente     | Tipo de servicio/recurso AWS                                         | vpc, eks, ecr, alb, aurora, kms, sg |
| funcionalidad  | Aplicación, servicio o funcionalidad de negocio                      | frontend, backend, core           |

### Implementación en módulos

Cada módulo define en `locals.tf`:

```hcl
locals {
  base_name     = "agat-${var.environment}"
  resource_name = "${local.base_name}-{componente}-${var.nombre_variable}"
}
```

El segmento `{componente}` (vpc, eks, aurora, etc.) **siempre se incluye en el local del módulo**, no se pasa como variable. Esto garantiza que la convención se aplique automáticamente sin intervención del usuario.

### Otros nombres

- **Modules sourced as**: `../../modules/{module-name}`

## Environment Variable Files

Environment-specific configuration lives in `layers/environment/{env}/{layer}/{env}.tfvars`. Each file defines:
- Project/environment identifiers
- CIDR blocks and subnet layout (3 AZs para prod y qa, 1 AZ para dev)
- Feature flags (create_read_replica, etc.)
- Sizing por ambiente (instancias, pods, memoria/cpu)
- Retention settings
- Corporate tags (`common_tags`)
