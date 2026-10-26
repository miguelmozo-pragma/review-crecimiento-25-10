# AGAT — Aplicación de Gestión Administrativa y Transaccional (IaC)

Infraestructura como código (Terraform) para la **Aplicación de Gestión Administrativa y Transaccional** de **Banca Global S.A.S.** Despliega sobre Amazon EKS una aplicación de 3 capas (frontend web, backend de microservicios y persistencia en Aurora PostgreSQL), con exposición **exclusivamente interna** y autenticación contra un **IdP externo**.

> **Alcance actual:** el proyecto se despliega de forma **local** y, por ahora, únicamente sobre el ambiente **`prod`** en `us-west-2`. La estructura soporta `dev` y `qa`, pero sus `tfvars` se habilitan cuando se requieran.
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
│   └── environment/
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
- Backend S3 de estado: `bgsas-prod-iac-terraform-state-gestion-admin` (us-west-2)

### Desplegar un layer

```bash
cd layers/<layer>

terraform init \
  -backend-config="bucket=bgsas-prod-iac-terraform-state-gestion-admin" \
  -backend-config="key=<layer>/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -input=false -reconfigure

terraform plan  -var-file=../environment/prod/<layer>/prod.tfvars -input=false
terraform apply -var-file=../environment/prod/<layer>/prod.tfvars -input=false
```

### Acceso al cluster

```bash
aws eks update-kubeconfig --name agat-prod-eks-core --region us-west-2
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

| Recurso                     | dev            | qa                | prod                  |
|-----------------------------|----------------|-------------------|-----------------------|
| AZs                         | 1              | 3                 | 3                     |
| Pods por deployment         | 1              | 3                 | 3                     |
| Memoria / CPU por pod       | 512 MB/256 mCPU| 512 MB/256 mCPU   | 1024 MB/512 mCPU      |
| Aurora                      | 1 writer       | writer + reader   | writer + reader (xl)  |

---

*Mantenido por el área de Soluciones Digitales. Documentación y comentarios en español; descripciones internas de módulos en inglés.*
