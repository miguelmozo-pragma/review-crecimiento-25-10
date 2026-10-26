---
inclusion: manual
---

# Skill: Prácticas de Seguridad

Guía de seguridad para la infraestructura IaC de la Aplicación de Gestión Administrativa y Transaccional (AGAT) sobre EKS.

## Cifrado con KMS

### Principio

Cada servicio que soporte cifrado con KMS Customer Managed Key (CMK) debe tener su propia key dedicada. NO se comparten keys entre servicios distintos.

### Keys requeridas

| Servicio            | Key Name     | Ejemplo nombre            |
|---------------------|--------------|---------------------------|
| Aurora PostgreSQL   | aurora       | agat-dev-kms-aurora       |
| Secrets Manager     | secrets      | agat-dev-kms-secrets      |
| CloudWatch Logs     | cw           | agat-dev-kms-cw           |

### Configuración estándar de KMS

```hcl
module "kms_aurora" {
  source = "../../modules/kms"
  providers = {
    aws.project = aws.project
  }

  project     = var.project
  environment = var.environment
  aws_region  = var.region

  key_name    = "aurora"
  description = "KMS key for Aurora PostgreSQL encryption"

  multi_region = false

  additional_tags = var.common_tags
}
```

### Rotación de keys

- `enable_key_rotation = true` (por defecto en el módulo)
- `rotation_period_in_days = 365` (por defecto)
- Rango permitido: 90-2560 días

### Políticas de KMS

Policy por defecto (cuenta root con acceso completo):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "EnableRootAccountAccess",
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::{account_id}:root" },
    "Action": "kms:*",
    "Resource": "*"
  }]
}
```

Para servicios AWS que necesiten acceso directo (RDS, S3, CloudWatch, DMS), agregar un Statement adicional con el Service Principal correspondiente.

## Checkov — Escaneo de Seguridad

### Qué es

Checkov es un escáner estático de IaC que valida compliance y mejores prácticas de seguridad.

### Cuándo usar skip

Solo cuando existe una justificación de negocio o técnica válida para aceptar el riesgo:

```hcl
resource "aws_xxx" "example" {
  #checkov:skip=CKV2_AWS_11:Razón del skip en español
  ...
}
```

### Reglas comunes que se skipean en este proyecto

| Check ID       | Descripción                                    | Justificación típica                    |
|----------------|------------------------------------------------|-----------------------------------------|
| CKV2_AWS_11    | VPC Flow Logs en formato personalizado         | Usamos formato default de AWS           |
| CKV_AWS_144    | S3 cross-region replication                    | No requerido para este alcance          |
| CKV_AWS_145    | S3 KMS encryption (vs SSE-S3)                  | SSE-S3 suficiente para logs temporales  |

### Reglas que NUNCA se skipean

- CKV_AWS_19: S3 encryption at rest (siempre cifrado)
- CKV_AWS_18: S3 access logging
- CKV2_AWS_6: S3 Block Public Access
- CKV_AWS_7: KMS key rotation enabled
- CKV_AWS_149: Secrets Manager encryption

## IAM — Principio de Mínimo Privilegio

### Despliegue local

- La IaC se despliega localmente usando el AWS CLI profile de cada ambiente
  (`agat_{env}`)
- El usuario/rol asociado al profile debe tener permisos para los dominios que
  gestiona cada layer (ver tabla de policies por dominio)
- Aplicar mínimo privilegio también al operador local: usar un rol/perfil por
  ambiente, no credenciales de administrador global

### Policies por dominio

| Dominio           | Permisos                                                       |
|-------------------|----------------------------------------------------------------|
| networking        | VPC, subnets, route tables, VPC endpoints, VPN, flow logs       |
| security          | KMS, IAM roles/policies, security groups, Secrets Manager      |
| compute           | EKS, node groups, ECR, ALB, CloudFront                         |
| storage           | S3, RDS/Aurora, ElastiCache, SSM                               |
| migration         | DMS, DataSync                                                   |
| management        | CloudWatch                                                      |

### Roles de servicio en EKS (IRSA)

- Los módulos de aplicación reciben el OIDC provider del clúster como variable
- Cada Service Account de Kubernetes se asocia a un IAM role vía IRSA
  (IAM Roles for Service Accounts)
- Los roles IRSA dan permisos mínimos al pod (ej. acceso a un bucket S3 o secret concreto)
- El addon AWS Load Balancer Controller usa su propio IAM role vía IRSA

### Reglas IAM en módulos

- No crear IAM roles/policies dentro de módulos de recursos (excepto service-linked roles e IRSA cuando el módulo lo gestione explícitamente)
- Los roles IAM base van en el layer de security
- Los módulos reciben ARNs de roles como variable de entrada

## S3 — Seguridad de Buckets

### Configuración obligatoria

```hcl
# Block public access (SIEMPRE)
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true

# Encryption
server_side_encryption_configuration {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Versioning (recomendado para datos, obligatorio para state)
versioning {
  enabled = true
}
```

### Acceso a S3 desde la VPC

- El acceso a S3 desde servicios dentro de la VPC usa un **VPC endpoint** (Gateway endpoint)
- El bucket policy restringe el acceso al VPC endpoint cuando aplique

### CloudFront + ALB (VPC Origin)

- La distribución pública de CloudFront se conecta al ALB mediante **VPC Origin**
- El ALB público solo acepta tráfico desde CloudFront
- Usar certificados ACM para TLS en CloudFront

## Aurora PostgreSQL — Seguridad

- Cifrado en reposo con KMS CMK dedicada (`storage_encrypted = true`)
- Credenciales gestionadas en Secrets Manager (con rotación)
- Security groups restringen acceso solo desde los security groups de los pods/nodos EKS
- Desplegado en subnets privadas (sin acceso público)
- TLS obligatorio para conexiones

## Red y Acceso

- El ALB administrativo es privado y se consume vía **VPN site-to-site** hacia las sedes
- Todas las cargas se ejecutan en subnets privadas
- Security groups con mínimo privilegio entre capas (ALB → nodos EKS → Aurora/Redis)

## Secrets y Parámetros

| Tipo de dato              | Dónde almacenar                              |
|---------------------------|----------------------------------------------|
| Configuración no sensible | SSM Parameter Store (String)                 |
| Configuración sensible    | SSM Parameter Store (SecureString) con KMS   |
| Credenciales de BBDD/DMS  | Secrets Manager con rotación                 |
| Variables de ambiente     | tfvars (NO secretos)                         |

### Regla fundamental

**NUNCA** almacenar secretos en:
- Archivos tfvars
- Código fuente
- Variables de Terraform sin marcar como `sensitive = true`
- Outputs sin marcar como `sensitive = true`

## Checklist de Seguridad para Nuevos Recursos

- [ ] Cifrado en reposo con KMS CMK dedicada
- [ ] Cifrado en tránsito (TLS 1.2+)
- [ ] Mínimo privilegio en IAM (IRSA para pods)
- [ ] Sin acceso público (a menos que sea explícitamente requerido, e.g., CloudFront)
- [ ] Recursos en subnets privadas
- [ ] Logging habilitado
- [ ] Tags corporativos aplicados
- [ ] Checkov scan sin errores (o skips justificados)
- [ ] Secrets en Secrets Manager o SSM SecureString
- [ ] Key rotation habilitada
