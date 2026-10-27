# Core Bancario — Infraestructura IaC (Migración a EKS)

Infraestructura como código (Terraform) para la migración del Core Bancario de **Banca Global S.A.S.** hacia una arquitectura *cloud-native* en AWS sobre Amazon EKS. El repositorio gestiona todo el ciclo de vida de la plataforma: red, cómputo, datos, exposición pública y la migración temporal de cargas desde el entorno on-premise.

> **Alcance actual:** el proyecto se despliega de forma **local** (sin pipeline de CI/CD para la propia IaC) en `us-west-2`. Los tres ambientes (**`dev`**, **`qa`**, **`prod`**) cuentan con sus archivos de variables (`tfvars`) parametrizados por dimensionamiento.

---

## 1. Objetivo de negocio

Modernizar y migrar el ecosistema de aplicaciones contenerizadas hacia una arquitectura resiliente, con tiempo de inactividad cercano a cero, optimizando el costo total de propiedad (TCO/OpEx) y asegurando previsibilidad financiera. La estrategia es **replatform**: las cargas ya están contenerizadas y se mueven a EKS, exponiendo al público únicamente el frontend y el módulo de estado de cuentas a través de CloudFront.

### Cargas de trabajo (microservicios)

| Módulo           | Namespace               | Exposición            |
|------------------|-------------------------|-----------------------|
| frontend         | `frontend`              | Pública (CloudFront)  |
| estado-cuentas   | `public-access`         | Pública (CloudFront)  |
| creditos         | `administrative-access` | Privada (VPN)         |
| recaudo          | `administrative-access` | Privada (VPN)         |
| inversiones      | `administrative-access` | Privada (VPN)         |
| administrativo   | `administrative-access` | Privada (VPN)         |

---

## 2. Arquitectura de alto nivel

Los diagramas siguen el modelo **C4**. El nivel *Container* muestra la topología multi-cuenta y la conectividad on-premise; el nivel *Component* detalla el interior del cluster EKS.

### 2.1 Vista Container (C4 nivel 2)

![Diagrama Container — Core Bancario on cloud](static_files/Diagramas%20review%20crecimiento-Container%20Core%20bancario%20%28on%20cloud%29.png)

Cada ambiente (**Prod**, **QA**, **Dev**) vive en su propia *Workload Account*. Prod y QA usan 3 AZs; Dev una sola. El acceso entra por un **Transit Gateway** central:

- **Usuario externo / cliente del banco** → CloudFront → *VPC Origin* → ALB interno → EKS.
- **Usuario administrativo** → IPSec VPN (site-to-site) → Transit Gateway → ALB interno administrativo → EKS.
- **DataSync Agent** y **servidores on-prem** en el *Corporate data center* alimentan la migración (DMS hacia Aurora, DataSync hacia S3).

Servicios transversales de cuenta: WAF, Route 53, CloudWatch, X-Ray, ACM, Shield, KMS, Secrets Manager, ECR.

### 2.2 Vista Component (C4 nivel 3) — EKS

![Diagrama Component — detalle del cluster EKS](static_files/Diagramas%20review%20crecimiento-Component%20core%20bancario%20migrado.png)

Dentro del cluster, cada microservicio se compone de `Service` + `Deployment` + `HPA` + `Pod`, organizados por namespace:

- **frontend** y **public-access**: expuestos vía el ALB conectado a CloudFront.
- **administrative-access** (créditos, recaudo, inversiones, administrativo): expuestos vía el ALB administrativo privado.
- **observability**: un pod **OpenTelemetry** que exporta métricas/trazas a CloudWatch.

Los pods leen credenciales de **Secrets Manager** y acceden a **Aurora** separando endpoint de **escritura (writer)** y **lectura (reader)**. La autorización pod→AWS es vía **IAM RBAC / IRSA**.

### 2.3 Decisiones de diseño clave

- **Sin exposición directa a internet del cómputo.** El único punto de entrada público es CloudFront, que alcanza un ALB **interno** mediante *VPC Origin*. El security group del ALB solo admite el *managed prefix list* de CloudFront.
- **Acceso administrativo privado** vía VPN site-to-site hacia un ALB interno dedicado.
- **Autoscaling con Karpenter**: un único node group de sistema arranca los addons; Karpenter aprovisiona el resto de capacidad bajo demanda.
- **Aislamiento por capas de red**: subnets `public` (NAT/IGW), `private` (cómputo) y `data` (bases de datos, sin salida a internet).
- **Cifrado en reposo con KMS CMK dedicada** por servicio (Aurora, Redis, S3, DMS).
- **Comunicación entre capas vía SSM Parameter Store** (desacople entre *layers*).

---

## 3. Estructura del repositorio

```
.
├── modules/                     # Módulos Terraform reutilizables
│   ├── vpc-module/              # VPC, subnets, routing, NAT, IGW, flow logs, VPC endpoints
│   ├── eks/                     # Cluster EKS + addons (LB Controller, EBS CSI, Karpenter)
│   ├── microservice/            # ECR + IRSA + SA + Deployment/Service/Ingress + pipeline CI/CD
│   ├── cloudfront/              # Distribución CloudFront + VPC Origin a ALB interno
│   ├── aurora/                  # Aurora PostgreSQL (writer + reader, KMS, secret)
│   ├── elasticache/             # ElastiCache Redis (replication group, KMS)
│   ├── s3/                      # Bucket S3 seguro (KMS, versioning, TLS, VPC endpoint policy)
│   └── dms/                     # DMS replication instance, endpoints, task, KMS, secret
│
├── layers/                      # Capas desplegables de forma independiente
│   ├── networking/              # VPC + subnets + NAT + endpoint S3 + flow logs
│   ├── workload/                # EKS + addons + Karpenter
│   ├── apps/                    # Namespaces + microservicios + pipelines
│   ├── data/                    # Aurora + Redis + S3
│   ├── cloudfront/              # CloudFront → ALB interno (VPC Origin)
│   ├── migration/               # DMS + DataSync (VPC endpoint + SG)
│   └── environment/             # Variables por ambiente (dev, qa, prod)
│       ├── dev/{layer}/dev.tfvars
│       ├── qa/{layer}/qa.tfvars
│       └── prod/{layer}/prod.tfvars
│
└── .kiro/steering/              # Convenciones del proyecto (naming, seguridad, estructura)
```

Cada *layer* contiene los cinco archivos estándar: `main.tf`, `providers.tf`, `variables.tf`, `data.tf`, `outputs.tf`.

---

## 4. Convenciones

### Nomenclatura

```
{carga}-{entorno}-{componente}-{funcionalidad}
```

- `carga`: siempre `cb` (Core Bancario)
- `entorno`: `dev`, `qa`, `prod`
- `componente`: tipo de recurso AWS (`vpc`, `eks`, `ecr`, `aurora`, `elasticache`, `s3`, `kms`, `dms`, `cf`, `alb`, `sg`, `secret`)
- `funcionalidad`: aplicación o servicio (`core`, `frontend`, `estado-cuentas`, `objetos`, …)

Ejemplos: `cb-prod-eks-core`, `cb-prod-aurora-core`, `cb-prod-s3-objetos`.

> El segmento `{componente}` se define como **literal** en el `locals.tf` de cada módulo — nunca se pasa como variable. Esto garantiza consistencia automática.

### Tags corporativos

Todos los recursos reciben `common_tags` vía `default_tags` del provider. **Los valores de tags no deben contener comas** (varios servicios AWS —RDS, ElastiCache, KMS— rechazan la coma en valores de tag).

### Provider

- Alias obligatorio `aws.project` en todos los recursos.
- `profile` vacío (`""`) usa el *default credential chain*.
- Los módulos que gestionan Kubernetes declaran además los providers `kubernetes`, `helm` y/o `kubectl`.

---

## 5. Orden de despliegue

Las capas tienen dependencias en cadena y se despliegan en este orden:

```
networking → workload → data → apps → cloudfront → migration
```

| Orden | Layer       | Depende de                               | Publica en SSM                        |
|-------|-------------|------------------------------------------|---------------------------------------|
| 1     | networking  | —                                        | vpc-id, cidr, subnets por tier        |
| 2     | workload    | networking (vpc, private-subnets)        | cluster name/endpoint, oidc arn       |
| 3     | data        | networking (vpc, data-subnets)           | endpoints Aurora/Redis, secret, bucket|
| 4     | apps        | workload (oidc, cluster)                 | ECR urls, roles IRSA, servicios       |
| 5     | cloudfront  | apps (ALB interno `cb-prod-alb-public`)  | distribution id/domain                |
| 6     | migration   | networking, data (Aurora endpoint)       | DMS arns, DataSync endpoint           |

> `migration` es **temporal**: se despliega solo durante la ventana de migración y se destruye al finalizar.

---

## 6. Operación

### Requisitos

- Terraform >= 1.0.0
- AWS CLI configurado (perfil `default` o el que corresponda)
- Backend S3 de estado por ambiente: `bgsas-{env}-iac-terraform-state-core-bancario` (us-west-2)

### Desplegar un layer

Sustituye `{env}` por `dev`, `qa` o `prod`:

```bash
cd layers/<layer>

terraform init \
  -backend-config="bucket=bgsas-{env}-iac-terraform-state-core-bancario" \
  -backend-config="key=<layer>/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -input=false -reconfigure

terraform plan  -var-file=../environment/{env}/<layer>/{env}.tfvars -input=false
terraform apply -var-file=../environment/{env}/<layer>/{env}.tfvars -input=false
```

> Cada ambiente usa su propio bucket de estado (`bgsas-dev-…`, `bgsas-qa-…`, `bgsas-prod-…`), que debe existir antes del primer `init`.

### Secretos

Nunca se almacenan secretos en `tfvars`. Las credenciales sensibles (p. ej. las passwords de DMS) se inyectan en tiempo de ejecución:

```bash
TF_VAR_dms_source_password='***' TF_VAR_dms_target_password='***' \
  terraform apply -var-file=../environment/prod/migration/prod.tfvars
```

Las credenciales generadas (Aurora) se almacenan automáticamente en **Secrets Manager** cifradas con KMS.

### Acceso al cluster

```bash
aws eks update-kubeconfig --name cb-{env}-eks-core --region us-west-2
kubectl get nodes
```

---

## 7. Seguridad

- **Cifrado en reposo** con KMS CMK dedicada por servicio (rotación anual habilitada).
- **Cifrado en tránsito** TLS 1.2+ en todos los extremos (CloudFront, Aurora, Redis).
- **IRSA** (IAM Roles for Service Accounts): cada microservicio asume un rol IAM de mínimo privilegio a través de su Service Account.
- **Sin acceso público** en cómputo ni datos; las bases viven en subnets aisladas.
- **Block Public Access** total en S3 + política que exige TLS y, opcionalmente, restringe al VPC endpoint.
- **Escaneo estático** con Checkov; los `skip` se documentan con justificación en el código.

---

## 8. Dimensionamiento por ambiente

Definido en `layers/environment/{env}/{layer}/{env}.tfvars`:

| Recurso                     | dev                       | qa                          | prod                        |
|-----------------------------|---------------------------|-----------------------------|-----------------------------|
| CIDR VPC                    | 10.10.0.0/16              | 10.20.0.0/16                | 10.0.0.0/16                 |
| AZs (red)                   | 2 *                       | 3                           | 3                           |
| EKS node group (sistema)    | t3.small (1)              | t3.medium (2)               | t3.medium (1)               |
| Pods por deployment         | 1 (128m / 256Mi)          | 3 (256m / 512Mi)            | 3 (256m / 512Mi)            |
| Aurora                      | t4g.medium, solo writer   | r6g.large, writer + reader  | r6g.xlarge, writer + reader |
| ElastiCache Redis           | t4g.micro, 1 nodo         | t4g.medium, 2 (multi-AZ)    | r6g.large, 2 (multi-AZ)     |
| DMS replication instance    | t3.medium (full-load)     | t3.large (full-load-and-cdc)| r6i.large (full-load-and-cdc)|
| Pipelines CI/CD (apps)      | deshabilitados            | habilitados                 | habilitados                 |

> \* El cómputo de `dev` usa 1 AZ, pero la **red** abarca 2 AZs porque los subnet groups de Aurora, EKS y ElastiCache exigen un mínimo de dos zonas de disponibilidad.

---

## Estimación de costos AWS

El repositorio incluye ejercicios de estimación de costos (us-west-2, On-Demand) por ambiente y un escenario de crecimiento. Costo mensual estimado de producción: **~$2,009/mes** (sin contar DMS temporal de migración, ~$1,768/mes).

| Escenario | Mensual | Anual | Archivo |
|-----------|--------:|------:|---------|
| dev | $565 | $6,783 | `estimacion_cb_dev.csv` |
| qa | $1,213 | $14,558 | `estimacion_cb_qa.csv` |
| prod | $2,009 | $24,105 | `estimacion_cb_prod.csv` |
| prod +50% (crecimiento) | $3,061 | $36,733 | `estimacion_cb_prod_plus50.csv` |

El driver de costo principal es **Aurora PostgreSQL** (writer + reader, ~50% del total). El análisis consolidado de las tres soluciones de la organización está en `../Estimacion_Costos_AWS_Consolidada.md`.

> Estimaciones de planeación, no una factura garantizada. No incluyen free tier ni descuentos por compromiso (Savings Plans / RI), por lo que representan una cota superior conservadora.

---

*Documentación y comentarios en español; descripciones internas de módulos en inglés.*
