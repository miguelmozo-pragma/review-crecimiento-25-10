# AGAT — Aplicación de Gestión Administrativa y Transaccional (IaC)

Infraestructura como código (Terraform) para la **Aplicación de Gestión Administrativa y Transaccional** de **Banca Global S.A.S.** Despliega sobre Amazon EKS una aplicación de 3 capas (frontend web, backend de microservicios y persistencia en Aurora PostgreSQL), con exposición **exclusivamente interna** y autenticación contra un **IdP externo**.

> **Alcance actual:** el proyecto se despliega de forma **local** en `us-west-2`. Los tres ambientes (**`dev`**, **`qa`**, **`prod`**) cuentan con sus archivos de variables (`tfvars`) parametrizados por dimensionamiento.
>
> Los módulos reutilizan los patrones del repositorio *Core Bancario migrado* (código de proyecto distinto: `agat`).

---

## 1. Objetivo de negocio

Permitir a Banca Global gestionar cuentas de clientes, autorizaciones de pagos y la administración interna, mediante una arquitectura de 3 capas, segura, de alta disponibilidad y resiliente.

- **Front-end**: aplicación web responsiva para usuarios internos y clientes.
- **Back-end**: microservicios de lógica de negocio, autenticación y autorización.
- **Persistencia**: base de datos relacional (Aurora PostgreSQL) con alta disponibilidad.

La autenticación y autorización de usuarios se resuelve consultando un **IdP externo**, alcanzable a través de la cuenta de Networking.

### Cargas de trabajo (microservicios)

| Módulo     | Namespace   | Exposición      |
|------------|-------------|-----------------|
| frontend   | `frontend`  | Interna (ALB)   |
| backend    | `backend`   | Interna (ALB)   |

---

## 2. Arquitectura de alto nivel

Los diagramas siguen el modelo **C4**. El nivel *Container* muestra la topología multi-cuenta y la conectividad; el *Component* detalla el interior del cluster EKS.

### 2.1 Vista Container (C4 nivel 2)

![Diagrama Container — AGAT](static%20_files/Diagramas%20review%20crecimiento-Container%20Aplicaci%C3%B3n%20de%20gestion%20administrativa%20y%20transaccional.png)

- Cada ambiente vive en su propia *Workload Account*; Prod y QA usan 3 AZs, Dev una sola.
- **No hay exposición pública directa**: toda la VPC es de **subnets privadas**. El acceso entra por un **Transit Gateway** central.
- **Usuario administrativo** → IPSec VPN (site-to-site) → Transit Gateway → ALB interno → EKS.
- Las aplicaciones en EKS **salen a consultar el IdP externo** a través de la cuenta de Networking (una *public subnet* con egress controlado).
- Servicios transversales: WAF, Route 53, CloudWatch, X-Ray, ACM, Shield, KMS.

### 2.2 Vista Component (C4 nivel 3) — EKS

![Diagrama Component — detalle del cluster EKS](static%20_files/Diagramas%20review%20crecimiento-Component%20Aplicaci%C3%B3n%20de%20gestion%20administrativa.png)

Dentro del cluster, cada microservicio se compone de `Service` + `Deployment` + `HPA` + `Pod`:

- **frontend**: aplicación web, expuesta vía ALB interno.
- **backend**: microservicios de lógica de negocio, expuestos vía ALB interno.
- **observability**: un pod **OpenTelemetry** que exporta métricas/trazas a CloudWatch.

Los pods acceden a **Aurora** separando endpoint de **escritura (writer)** y **lectura (reader)**, leen credenciales de **Secrets Manager** y usan **IAM RBAC / IRSA** para autorizarse contra AWS.

### 2.3 Decisiones de diseño clave

- **Sin exposición pública del cómputo**: la VPC es privada; el único acceso es interno (VPN + ALB interno).
- **Autoscaling con Karpenter**: un node group de sistema arranca los addons; Karpenter aprovisiona el resto bajo demanda.
- **Aislamiento por capas de red**: subnets `public` (egress hacia el IdP vía NAT), `private` (cómputo) y `data` (Aurora, sin salida a internet).
- **Cifrado en reposo con KMS CMK dedicada** (Aurora, Secrets).
- **Comunicación entre capas vía SSM Parameter Store**.

---

## 3. Estructura del repositorio

```
.
├── modules/                     # Módulos Terraform reutilizables
│   ├── vpc-module/              # VPC, subnets, routing, NAT, IGW, flow logs
│   ├── eks/                     # Cluster EKS + addons (LB Controller, EBS CSI, Karpenter)
│   ├── microservice/            # ECR + IRSA + SA + Deployment/Service/Ingress + pipeline CI/CD
│   └── aurora/                  # Aurora PostgreSQL (writer + reader, KMS, secret)
│
├── layers/                      # Capas desplegables de forma independiente
│   ├── networking/              # VPC + subnets + NAT + flow logs
│   ├── workload/                # EKS + addons + Karpenter
│   ├── data/                    # Aurora PostgreSQL
│   ├── apps/                    # Namespaces + microservicios + pipelines
│   └── environment/             # Variables por ambiente (dev, qa, prod)
│       ├── dev/{layer}/dev.tfvars
│       ├── qa/{layer}/qa.tfvars
│       └── prod/{layer}/prod.tfvars
│
└── .kiro/steering/              # Convenciones del proyecto
```

Cada *layer* contiene los cinco archivos estándar: `main.tf`, `providers.tf`, `variables.tf`, `data.tf`, `outputs.tf`.

---

## 4. Convenciones

### Nomenclatura

```
{carga}-{entorno}-{componente}-{funcionalidad}
```

- `carga`: siempre `agat`
- `entorno`: `dev`, `qa`, `prod`
- `componente`: tipo de recurso AWS (`vpc`, `eks`, `ecr`, `aurora`, `kms`, `sg`, `alb`)
- `funcionalidad`: aplicación o servicio (`core`, `frontend`, `backend`)

Ejemplos: `agat-prod-eks-core`, `agat-prod-aurora-core`, `agat-prod-ecr-frontend`.

> El segmento `{componente}` se define como **literal** en el `locals.tf` de cada módulo — nunca se pasa como variable.

### Tags corporativos

Todos los recursos reciben `common_tags` vía `default_tags` del provider. **Los valores de tags no deben contener comas** (varios servicios AWS —RDS, KMS— las rechazan).

### Provider

- Alias obligatorio `aws.project`.
- `profile` vacío (`""`) usa el *default credential chain*.
- Los layers que gestionan Kubernetes declaran además los providers `kubernetes`, `helm` y/o `kubectl`.

---

## 5. Orden de despliegue

```
networking → workload → data → apps
```

| Orden | Layer       | Depende de                          | Publica en SSM                   |
|-------|-------------|-------------------------------------|----------------------------------|
| 1     | networking  | —                                   | vpc-id, cidr, subnets por tier   |
| 2     | workload    | networking (vpc, private-subnets)   | cluster name/endpoint, oidc arn  |
| 3     | data        | networking (vpc, data-subnets)      | endpoints Aurora, secret         |
| 4     | apps        | workload (oidc, cluster)            | ECR urls, roles IRSA, servicios  |

---

## 6. Operación

### Requisitos

- Terraform >= 1.0.0
- AWS CLI configurado
- Backend S3 de estado por ambiente: `bgsas-{env}-iac-terraform-state-gestion-admin` (us-west-2)

### Desplegar un layer

Sustituye `{env}` por `dev`, `qa` o `prod`:

```bash
cd layers/<layer>

terraform init \
  -backend-config="bucket=bgsas-{env}-iac-terraform-state-gestion-admin" \
  -backend-config="key=<layer>/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -input=false -reconfigure

terraform plan  -var-file=../environment/{env}/<layer>/{env}.tfvars -input=false
terraform apply -var-file=../environment/{env}/<layer>/{env}.tfvars -input=false
```

> Cada ambiente usa su propio bucket de estado (`bgsas-dev-…`, `bgsas-qa-…`, `bgsas-prod-…`), que debe existir antes del primer `init`.

### Acceso al cluster

```bash
aws eks update-kubeconfig --name agat-{env}-eks-core --region us-west-2
kubectl get nodes
```

### Secretos

Nunca se almacenan secretos en `tfvars`. Las credenciales generadas (Aurora) se guardan en **Secrets Manager** cifradas con KMS.

---

## 7. Seguridad

- **Cifrado en reposo** con KMS CMK dedicada (rotación anual).
- **Cifrado en tránsito** TLS 1.2+.
- **IRSA**: cada microservicio asume un rol IAM de mínimo privilegio vía su Service Account.
- **Sin acceso público** en cómputo ni datos; todo en subnets privadas, acceso por VPN.
- **MFA e IdP externo** para autenticación de usuarios (resuelto a nivel de aplicación).

---

## 8. Dimensionamiento por ambiente

Definido en `layers/environment/{env}/{layer}/{env}.tfvars`:

| Recurso                     | dev                      | qa                         | prod                        |
|-----------------------------|--------------------------|----------------------------|-----------------------------|
| CIDR VPC                    | 10.10.0.0/16             | 10.20.0.0/16               | 10.0.0.0/16                 |
| AZs (red)                   | 2 *                      | 3                          | 3                           |
| EKS node group (sistema)    | t3.small (1)             | t3.medium (2)              | t3.medium (1)               |
| Pods por deployment         | 1 (128m / 256Mi)         | 3 (256m / 512Mi)           | 3 (256m / 512Mi)            |
| Aurora                      | t4g.medium, solo writer  | r6g.large, writer + reader | r6g.xlarge, writer + reader |
| Pipelines CI/CD (apps)      | deshabilitados           | habilitados                | habilitados                 |

> \* El cómputo de `dev` usa 1 AZ, pero la **red** abarca 2 AZs porque los subnet groups de Aurora y EKS exigen un mínimo de dos zonas de disponibilidad.

---

## Estimación de costos AWS

El repositorio incluye ejercicios de estimación de costos (us-west-2, On-Demand) por ambiente y un escenario de crecimiento. Costo mensual estimado de producción: **~$1,419/mes** — la más económica de las tres soluciones de la organización por ser estructuralmente más simple (2 microservicios, exposición interna, sin CloudFront/Redis/S3).

| Escenario | Mensual | Anual | Archivo |
|-----------|--------:|------:|---------|
| dev | $242 | $2,900 | `estimacion_agat_dev.csv` |
| qa | $779 | $9,344 | `estimacion_agat_qa.csv` |
| prod | $1,419 | $17,029 | `estimacion_agat_prod.csv` |
| prod +50% (crecimiento) | $2,567 | $30,799 | `estimacion_agat_prod_plus50.csv` |

El driver de costo principal es **Aurora PostgreSQL** (writer + reader, ~71% del total). El análisis consolidado de las tres soluciones está en `../Estimacion_Costos_AWS_Consolidada.md`.

> Estimaciones de planeación, no una factura garantizada. No incluyen free tier ni descuentos por compromiso (Savings Plans / RI), por lo que representan una cota superior conservadora.

---

*Documentación y comentarios en español; descripciones internas de módulos en inglés.*
