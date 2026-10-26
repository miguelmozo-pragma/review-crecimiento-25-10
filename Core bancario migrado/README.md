# Core Bancario — Infraestructura IaC (Migración a EKS)

Infraestructura como código (Terraform) para la migración del Core Bancario de **Banca Global S.A.S.** hacia una arquitectura *cloud-native* en AWS sobre Amazon EKS. El repositorio gestiona todo el ciclo de vida de la plataforma: red, cómputo, datos, exposición pública y la migración temporal de cargas desde el entorno on-premise.

> **Alcance actual:** el proyecto se despliega de forma **local** (sin pipeline de CI/CD para la propia IaC) y, por ahora, únicamente sobre el ambiente **`prod`** en `us-west-2`. La estructura soporta `dev` y `qa`, pero sus `tfvars` se habilitan cuando se requieran.

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
│   └── environment/
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
- Backend S3 de estado: `bgsas-prod-iac-terraform-state-core-bancario` (us-west-2)

### Desplegar un layer

```bash
cd layers/<layer>

terraform init \
  -backend-config="bucket=bgsas-prod-iac-terraform-state-core-bancario" \
  -backend-config="key=<layer>/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -input=false -reconfigure

terraform plan  -var-file=../environment/prod/<layer>/prod.tfvars -input=false
terraform apply -var-file=../environment/prod/<layer>/prod.tfvars -input=false
```

### Secretos

Nunca se almacenan secretos en `tfvars`. Las credenciales sensibles (p. ej. las passwords de DMS) se inyectan en tiempo de ejecución:

```bash
TF_VAR_dms_source_password='***' TF_VAR_dms_target_password='***' \
  terraform apply -var-file=../environment/prod/migration/prod.tfvars
```

Las credenciales generadas (Aurora) se almacenan automáticamente en **Secrets Manager** cifradas con KMS.

### Acceso al cluster

```bash
aws eks update-kubeconfig --name cb-prod-eks-core --region us-west-2
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

| Recurso                     | dev            | qa                | prod                  |
|-----------------------------|----------------|-------------------|-----------------------|
| AZs                         | 1              | 3                 | 3                     |
| Pods por deployment         | 1              | 3                 | 3                     |
| Aurora                      | 1 writer       | writer + reader   | writer + reader (xl)  |
| ElastiCache Redis           | pequeña        | mediana           | grande (multi-AZ)     |
| DMS replication instance    | pequeña        | mediana           | grande                |

---

*Mantenido por el área de Soluciones Digitales. Documentación y comentarios en español; descripciones internas de módulos en inglés.*
