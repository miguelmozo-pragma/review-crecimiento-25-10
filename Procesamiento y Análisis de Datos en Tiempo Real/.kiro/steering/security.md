---
inclusion: manual
---

# Skill: Prácticas de Seguridad

Guía de seguridad para la infraestructura IaC del pipeline de Procesamiento y Análisis de Datos en Tiempo Real (RTDA).

## Cifrado con KMS

### Principio

Cada servicio que soporte cifrado con KMS Customer Managed Key (CMK) debe tener su propia key dedicada. NO se comparten keys entre servicios distintos.

### Keys requeridas

| Servicio                 | Key Name     | Ejemplo nombre              |
|--------------------------|--------------|-----------------------------|
| Kinesis Data Stream      | kinesis      | rtda-prod-kms-kinesis       |
| S3 (raw / data lake)     | s3           | rtda-prod-kms-s3            |
| SNS                      | sns          | rtda-prod-kms-sns           |
| Fraud Detector S3        | fraud        | rtda-prod-kms-fraud         |
| CloudWatch Logs          | cw           | rtda-prod-kms-cw            |

- Kinesis: usar `StreamEncryption` con `KMS` y la CMK dedicada.
- Firehose: cifrado del delivery stream y, en destino, S3 con SSE-KMS.
- S3: SSE-KMS obligatorio en raw y data lake, con bucket key habilitado.
- SNS: `kms_master_key_id` con la CMK de SNS para tópicos con datos sensibles.
- Rotación: `enable_key_rotation = true`, `rotation_period_in_days = 365`.

## Lake Formation

- El Data Lake en S3 se gobierna con **Lake Formation**, no solo con políticas IAM de bucket.
- Registrar la ubicación S3 del data lake en Lake Formation (`aws_lakeformation_resource`).
- Conceder permisos de grano fino (`aws_lakeformation_permissions`) por database/tabla a los principales autorizados (roles de Flink, analistas, Glue).
- Principio de mínimo privilegio: los analistas reciben `SELECT` sobre las tablas/columnas necesarias, no acceso directo al bucket.
- Evitar `IAMAllowedPrincipals` por defecto en databases nuevas.

## IAM — Roles de servicio (mínimo privilegio)

Cada servicio gestionado recibe un rol dedicado con permisos acotados:

| Servicio        | Permisos clave                                                        |
|-----------------|-----------------------------------------------------------------------|
| Firehose        | leer del Kinesis stream, escribir en S3, usar la CMK de S3, logs      |
| Flink (MSAF)    | leer del Kinesis stream, invocar Fraud Detector, escribir en S3/logs  |
| Lambda          | leer del origen (stream/evento), publicar en SNS, logs, CMK           |
| Fraud Detector  | leer datos de entrenamiento en S3, su CMK, publicar métricas          |

- Los roles IAM van en el layer que los consume; se pasan a los módulos como variable cuando ya existen, o los crea el módulo del servicio cuando es un rol de ejecución propio (Lambda, Flink).
- No usar `*` en acciones/recursos salvo donde el servicio lo exija (documentar con `checkov:skip`).

## Cifrado en tránsito

- TLS 1.2+ en todos los endpoints (Kinesis, Firehose, SNS, Lambda, S3).
- Las llamadas entre servicios usan los endpoints HTTPS de AWS.

## S3 — Seguridad de Buckets (raw y data lake)

```hcl
# Block public access (SIEMPRE)
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true

# Encryption
sse_algorithm     = "aws:kms"
kms_master_key_id = var.kms_key_arn
bucket_key_enabled = true

# Versioning + lifecycle para raw (expiración/transición a clases frías)
```

## Checkov — Escaneo de Seguridad

### Reglas que NUNCA se skipean

- CKV_AWS_19 / CKV_AWS_145: S3 encryption at rest (KMS)
- CKV2_AWS_6: S3 Block Public Access
- CKV_AWS_7: KMS key rotation enabled
- CKV_AWS_158: CloudWatch log group encryption
- Kinesis: encryption at rest con CMK

### Cuándo usar skip

Solo con justificación de negocio/técnica documentada:

```hcl
resource "aws_xxx" "example" {
  #checkov:skip=CKV_XXX:Razón del skip en español
  ...
}
```

## Secrets y Parámetros

| Tipo de dato              | Dónde almacenar                              |
|---------------------------|----------------------------------------------|
| Configuración no sensible | SSM Parameter Store (String)                 |
| Configuración sensible    | SSM Parameter Store (SecureString) con KMS   |
| Credenciales externas     | Secrets Manager con rotación                 |
| Variables de ambiente     | tfvars (NO secretos)                         |

## Checklist de Seguridad para Nuevos Recursos

- [ ] Cifrado en reposo con KMS CMK dedicada
- [ ] Cifrado en tránsito (TLS 1.2+)
- [ ] Mínimo privilegio en IAM (rol dedicado por servicio)
- [ ] Data Lake gobernado con Lake Formation (no solo IAM)
- [ ] S3 sin acceso público
- [ ] Logging habilitado (CloudWatch) y cifrado
- [ ] Tags corporativos aplicados (sin comas en los valores)
- [ ] Checkov scan sin errores (o skips justificados)
- [ ] Key rotation habilitada
