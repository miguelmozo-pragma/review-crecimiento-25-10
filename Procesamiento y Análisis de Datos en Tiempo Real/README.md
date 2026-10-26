# RTDA — Procesamiento y Análisis de Datos en Tiempo Real

Infraestructura como código (Terraform) para un pipeline **serverless de streaming y analítica en tiempo real** en AWS, orientado a **detección de fraude** y análisis de comportamiento de clientes.

El código de proyecto es `rtda` y la infraestructura se despliega en tres ambientes: **dev**, **qa** y **prod**.

---

## Arquitectura

![Arquitectura RTDA](static%20_files/Diagramas%20review%20crecimiento-Container%20Procesamiento%20y%20an%C3%A1lisis%20de%20datos.png)

El diagrama muestra dos dominios:

- **Workload Account Prod** (izquierda): la fuente de datos (Internal ALB → EKS → BD Aurora, con CDC). **Fuera del alcance de este repositorio.**
- **Data and Analytics** (derecha): el pipeline que **sí** gestiona este repo, dividido en cuatro etapas.

### Etapas del pipeline

| Etapa | Servicios (diagrama) | Qué gestiona este repo |
|-------|----------------------|------------------------|
| **Ingesta** | Kinesis Data Stream → Kinesis Data Firehose | Stream + Firehose entregando a S3 raw |
| **Almacenamiento** | S3, Glue Data Catalog, Lake Formation | Buckets S3 (raw / data lake) + gobierno con Lake Formation |
| **Procesamiento** | Kinesis for Apache Flink, Fraud Detector, Athena | App Flink + recursos periféricos de Fraud Detector |
| **Consumo** | Lambda (Notificar fraude) → SNS → Analistas | Lambda de evento de fraude + tópico SNS |

> **Nota sobre el diagrama:** algunos componentes dibujados (Athena, EventBridge, Amazon QuickSight/"Quick Suite") son parte de la visión de consumo/analítica pero **no están implementados** en este repo en su estado actual. El consumo implementado es **Lambda → SNS**. Los servicios transversales del diagrama (CloudWatch, KMS, IAM) sí se aplican en todos los módulos.

### Flujo de datos

```
Fuente (fuera de alcance)
        │
        ▼
 Kinesis Data Stream  ──►  Kinesis Data Firehose  ──►  S3 (raw)
        │
        ▼
 Managed Service for Apache Flink  ──►  AWS Fraud Detector (GetEventPrediction)
        │                                   
        ▼                                   
 S3 (data lake)  ◄── gobernado por ──  Lake Formation + Glue Data Catalog
        │
        ▼
 Lambda (evento de fraude)  ──►  SNS (notificación)  ──►  Analistas / Core bancario
```

---

## Estructura del repositorio

```
.
├── layers/                      # Capas desplegables de forma independiente
│   ├── storage/                 # S3 (raw + data lake) + Lake Formation
│   ├── ingestion/               # Kinesis Data Stream + Firehose
│   ├── processing/              # Flink + Fraud Detector (periféricos)
│   ├── consumption/             # Lambda (evento de fraude) + SNS
│   └── environment/             # tfvars por ambiente
│       ├── dev/{layer}/dev.tfvars
│       ├── qa/{layer}/qa.tfvars
│       └── prod/{layer}/prod.tfvars
├── modules/                     # Módulos reutilizables
│   ├── kinesis/                 # Kinesis Data Stream + KMS
│   ├── firehose/                # Firehose delivery stream → S3 + IAM + CloudWatch
│   ├── s3/                      # Bucket S3 (SSE-KMS) + KMS
│   ├── lakeformation/           # Registro S3, Glue DB, permisos de grano fino
│   ├── flink/                   # Managed Service for Apache Flink + IAM + CloudWatch
│   ├── fraud-detector/          # Periféricos de Fraud Detector (ver limitaciones)
│   ├── lambda/                  # Lambda + IAM + CloudWatch + alarma
│   └── sns/                     # Tópico SNS (SSE-KMS) + suscripciones + KMS
├── static _files/               # Diagrama de arquitectura
└── product.md                   # Objetivo de negocio y requerimiento
```

Cada layer sigue la convención de archivos: `main.tf`, `providers.tf`, `variables.tf`, `data.tf`, `outputs.tf`.

---

## Convenciones

### Nomenclatura

```
{carga}-{entorno}-{componente}-{funcionalidad}
```

Ejemplos: `rtda-dev-kinesis-ingesta`, `rtda-prod-s3-datalake`, `rtda-dev-lambda-evento-fraude`, `rtda-dev-sns-fraude`.

El segmento `{componente}` se define siempre como literal en el `locals.tf` de cada módulo; nunca se pasa como variable.

### Provider

- Alias obligatorio `aws.project` con `default_tags` (tags corporativos).
- Variable `profile`: vacía (`""`) usa el default credential chain; de lo contrario, usa el AWS CLI profile indicado.
- Versión del provider AWS `>= 5.0.0`.

### Comunicación entre layers

Vía **SSM Parameter Store**, con el patrón `/rtda/{environment}/{layer}/{recurso}`. Cada layer publica sus outputs y los consumidores los leen en `data.tf`.

---

## Requisitos previos

- **Terraform** >= 1.0.0
- **AWS CLI** con credenciales activas (o un profile configurado).
- Bucket S3 existente para el **state de Terraform** (se pasa vía `-backend-config`).
- Permisos IAM suficientes para crear Kinesis, Firehose, S3, KMS, Lake Formation/Glue, Managed Service for Apache Flink, Lambda, SNS, IAM y CloudWatch.

---

## Orden de despliegue

Las capas tienen dependencias entre sí (resueltas vía SSM), por lo que deben desplegarse en este orden:

```
storage → ingestion → processing → consumption
```

- **storage**: crea el Data Lake (S3 + Lake Formation) del que dependen las demás.
- **ingestion**: Kinesis + Firehose; el Firehose entrega al bucket raw de storage.
- **processing**: Flink consume del stream de ingestion y escribe/lee del data lake de storage.
- **consumption**: Lambda + SNS; la Lambda lee del stream de ingestion.

---

## Cómo desplegar

La IaC se despliega de forma **local** con el AWS CLI profile correspondiente a cada ambiente. Reemplazar `{env}` por `dev`, `qa` o `prod`, y `{layer}` por la capa.

```bash
cd layers/{layer}

# 1. Inicializar (la config del backend se pasa externamente)
terraform init \
  -backend-config="bucket=<bucket-del-state>" \
  -backend-config="key={layer}/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -input=false -reconfigure

# 2. Plan
terraform plan  -var-file=../environment/{env}/{layer}/{env}.tfvars -input=false

# 3. Apply
terraform apply -var-file=../environment/{env}/{layer}/{env}.tfvars -input=false
```

> El `key` del state se organiza por capa (p. ej. `storage/terraform.tfstate`). Si se usa un mismo bucket de state para varios ambientes, conviene prefijar el `key` por ambiente (p. ej. `dev/storage/terraform.tfstate`) para no mezclar states.

---

## Seguridad

- **KMS CMK dedicada por servicio** (no se comparten keys). Cada módulo que soporta cifrado crea su propia CMK con rotación anual: `rtda-{env}-kms-{servicio}-{funcionalidad}` (kinesis, s3, sns, fraud, y `cw` para cada log group).
- **S3**: SSE-KMS obligatorio + bucket key + *block public access* total + versioning.
- **CloudWatch Logs**: cada log group se cifra con una CMK dedicada cuya *key policy* autoriza al servicio `logs.{region}.amazonaws.com` (condicionada al ARN del log group).
- **Lake Formation**: el data lake se gobierna con permisos de grano fino (`aws_lakeformation_permissions`) en lugar de solo políticas de bucket IAM. No se concede `IAMAllowedPrincipals` por defecto.
- **IAM mínimo privilegio**: cada servicio gestionado recibe un rol dedicado con permisos acotados (sin `*` salvo donde el servicio lo exige, documentado).
- **Secretos**: no van en tfvars; se usan SSM Parameter Store / Secrets Manager.

---

## Limitaciones conocidas

Estas tres decisiones son importantes para operar el pipeline correctamente:

### 1. AWS Fraud Detector — gestionado fuera de Terraform

El provider AWS de Terraform **no soporta recursos nativos `aws_frauddetector_*`**. El detector y sus componentes (variables, labels, event type, outcomes, rules, models) **se crean fuera de Terraform** (consola / CLI / API), o mediante un stack de CloudFormation `AWS::FraudDetector::*` gestionado aparte.

El módulo `modules/fraud-detector` gestiona **solo los recursos periféricos** que sí soporta Terraform:
- CMK dedicada de datos (`rtda-{env}-kms-fraud-{func}`)
- Bucket S3 de datos de entrenamiento (SSE-KMS, privado)
- CMK + log group de CloudWatch
- Rol de servicio IAM (`frauddetector.amazonaws.com`) con mínimo privilegio

> El rol de ejecución de Flink concede `frauddetector:GetEventPrediction` sobre `*` porque el ARN del detector no existe en el state de Terraform. Conviene **acotarlo** una vez creado el detector.

### 2. Flink — artefacto de código placeholder

La aplicación de Managed Service for Apache Flink requiere que **exista un artefacto de código (ZIP con un JAR válido) en S3** al momento de crear el recurso, incluso con `start_application = false`.

- El artefacto se espera en `s3://rtda-{env}-s3-datalake/flink-code/app.zip`.
- En el despliegue inicial se subió un **placeholder** (un JAR vacío con solo el manifest) que permite que la aplicación exista pero **no procesa nada**.
- Antes de poner `flink_start_application = true`, reemplazar el placeholder por el JAR real (vía pipeline o subida manual) y volver a aplicar.

### 3. Lambda — código placeholder y pipeline externo

El código de la Lambda de evento de fraude se despliega **por fuera de Terraform** (pipeline / paquete en S3).

- El layer `consumption` empaqueta un **placeholder** local (`layers/consumption/placeholder/app.py`) que solo devuelve un eco, para que el primer `apply` funcione sin un bucket de artefactos.
- El módulo `lambda` usa `lifecycle.ignore_changes` sobre el código, de modo que Terraform **no pisa** el artefacto cuando el pipeline lo actualice.
- El módulo `lambda` de este repo **no incluye** el pipeline CI/CD cross-account (CodePipeline/CodeBuild/ECR) del repositorio de referencia; el despliegue del código se gestiona de forma independiente.

---

## Outputs publicados en SSM

| Layer | Parámetros (`/rtda/{env}/...`) |
|-------|-------------------------------|
| storage | `storage/raw-bucket-name\|arn`, `storage/raw-kms-key-arn`, `storage/datalake-bucket-name\|arn`, `storage/datalake-kms-key-arn`, `storage/datalake-database-name` |
| ingestion | `ingestion/kinesis-stream-arn\|name`, `ingestion/kinesis-kms-key-arn`, `ingestion/firehose-delivery-stream-arn` |
| processing | `processing/flink-application-arn\|name`, `processing/fraud-service-role-arn`, `processing/fraud-data-kms-key-arn` |
| consumption | `consumption/sns-topic-arn`, `consumption/lambda-function-arn\|name` |

---

## Dimensionamiento por ambiente

| Recurso | dev | qa | prod |
|---------|-----|----|------|
| Kinesis (modo) | ON_DEMAND | ON_DEMAND | PROVISIONED (2 shards) |
| Firehose buffering (MB / s) | 5 / 300 | 5 / 120 | 64 / 60 |
| Flink paralelismo (KPU) | 1 | 2 | 4 |
| Lambda memoria / timeout | 256 / 30 | 512 / 60 | 1024 / 60 |
| Retención de logs (días) | 30 | 30 | 90 |
| S3 lifecycle (días a IA) | 30 | 60 | 90 |

---

## Estimación de costos AWS

El repositorio incluye ejercicios de estimación de costos (us-west-2, On-Demand) por ambiente y un escenario de crecimiento. Costo mensual estimado de producción: **~$1,929/mes**.

| Escenario | Mensual | Anual | Archivo |
|-----------|--------:|------:|---------|
| dev | $334 | $4,008 | `estimacion_rtda_dev.csv` |
| qa | $818 | $9,819 | `estimacion_rtda_qa.csv` |
| prod | $1,929 | $23,150 | `estimacion_rtda_prod.csv` |
| prod +50% (crecimiento) | $2,820 | $33,843 | `estimacion_rtda_prod_plus50.csv` |

### Supuesto clave: pre-filtro de fraude

El driver de costo de esta solución es **AWS Fraud Detector**. El modelo asume que un **pre-filtro de reglas en Flink descarta ~90% de las transacciones** evidentemente legítimas antes de invocar el detector; solo el 10% restante llega a Fraud Detector (y de ese 10%, la mayoría por reglas y una fracción por ML). Este patrón reduce el costo de producción de **~$11,954/mes (todas las transacciones al detector) a ~$1,929/mes (−84%)** sin degradar la capacidad de detección, siempre que las reglas de pre-filtrado estén bien calibradas.

El resto del pipeline (Kinesis, Firehose, S3, Flink, Lake Formation) cuesta en conjunto ~$500/mes. El análisis consolidado de las tres soluciones está en `../Estimacion_Costos_AWS_Consolidada.md`.

> Estimaciones de planeación, no una factura garantizada. No incluyen free tier ni descuentos por compromiso (Savings Plans / RI), por lo que representan una cota superior conservadora.

---

*Mantenido por el área de Soluciones Digitales. Documentación y comentarios en español; descripciones internas de módulos en inglés.*
