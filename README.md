# Infraestructura como Código — Banca Global S.A.S.

Monorepo de infraestructura en **Terraform** para las soluciones cloud de Banca Global S.A.S. en AWS. Agrupa tres plataformas independientes, cada una con sus propios módulos, layers, ambientes y documentación.

> **Contexto:** todas las soluciones se despliegan de forma **local** (sin CI/CD para la propia IaC) sobre **AWS us-west-2**, con ambientes **dev / qa / prod**. El despliegue de código de las aplicaciones sí usa pipelines (CodePipeline/CodeBuild), gestionados dentro de cada solución.

---

## Contexto de la solución (C4 — Nivel 1)

![Diagrama de Contexto C4 — Solución en la nube Banca Global](static_files/Diagramas%20review%20crecimiento-Contexto%20C4%20Solucion%20Cloud.png)

El diagrama de contexto muestra la visión global de la plataforma en la nube y cómo se relacionan sus tres sistemas:

- **Actores:** el *Cliente Externo* (consulta estado de cuenta por internet, HTTPS), el *Operador Bancario/Administrativo* (personal de la sede central y las 10 sedes departamentales) y el *Equipo TI / Operaciones*.
- **Conectividad:** las sedes se conectan de forma segura mediante **VPN IPSec site-to-site**; el tráfico público entra por el **perímetro de red y seguridad** (NAT, WAF, concentrador VPN).
- **Sistemas (las tres soluciones de este repo):**
  - **Sistema Core Bancario** — procesa la lógica transaccional (créditos, recaudo, inversiones), estados de cuenta y administración.
  - **Nuevo Módulo de Gestión Administrativa** — gestión de cuentas, autorizaciones de pago y administración interna.
  - **Nuevo sistema de Procesamiento y Análisis en Tiempo Real** — analítica de streaming, detección de fraude y análisis de comportamiento.
- **Observabilidad:** CloudWatch centraliza trazas, métricas y logs de la plataforma.

Cada sistema cuenta además con sus propios diagramas C4 de nivel Container y Component en el `static_files/` de su respectiva carpeta.

---

## Soluciones

| Solución | Descripción | Stack principal | Prod (est.) |
|----------|-------------|-----------------|------------:|
| [**Core Bancario**](./Core%20bancario%20migrado/) | Migración del core a arquitectura *cloud-native* | EKS · Aurora · Redis · CloudFront · DMS | ~$2,009/mes |
| [**Gestión Administrativa (AGAT)**](./Aplicacion%20de%20Gestion%20Administrativa%20y%20Transaccional/) | App de gestión administrativa y transaccional (3 capas) | EKS · Aurora (interno, sin exposición pública) | ~$1,419/mes |
| [**Procesamiento Tiempo Real (RTDA)**](./Procesamiento%20y%20An%C3%A1lisis%20de%20Datos%20en%20Tiempo%20Real/) | Pipeline de streaming y detección de fraude | Kinesis · Firehose · Flink · Fraud Detector · SNS | ~$1,929/mes |

Cada solución tiene su propio `README.md` con arquitectura (diagramas C4), estructura, convenciones, orden de despliegue y operación.

---

## Estructura del monorepo

```
Terraform iac/
├── Core bancario migrado/                      # Solución 1: migración a EKS
│   ├── modules/        (vpc-module, eks, microservice, cloudfront, aurora, elasticache, s3, dms)
│   ├── layers/         (networking, workload, data, apps, cloudfront, migration)
│   ├── .kiro/steering/ (convenciones del proyecto)
│   └── README.md
│
├── Aplicacion de Gestion Administrativa y Transaccional/   # Solución 2: AGAT
│   ├── modules/        (vpc-module, eks, microservice, aurora)
│   ├── layers/         (networking, workload, data, apps)
│   ├── .kiro/steering/
│   └── README.md
│
├── Procesamiento y Análisis de Datos en Tiempo Real/       # Solución 3: RTDA
│   ├── (modules / layers por implementar)
│   ├── .kiro/steering/
│   └── README.md
│
├── Estimacion_Costos_AWS_Consolidada.md        # Análisis de costos de las 3 soluciones
└── README.md                                   # Este archivo
```

---

## Convenciones comunes

Las tres soluciones comparten el mismo conjunto de prácticas (documentadas en el `.kiro/steering/` de cada una):

- **Nomenclatura:** `{carga}-{entorno}-{componente}-{funcionalidad}`, con códigos de proyecto `cb` (Core Bancario), `agat` (Gestión Administrativa) y `rtda` (Procesamiento Tiempo Real).
- **Layers independientes:** cada capa se despliega por separado y se comunica con las demás vía **SSM Parameter Store**.
- **Provider:** alias `aws.project` con `default_tags` corporativos. `profile` vacío usa el *default credential chain*.
- **Backend de estado:** S3 por ambiente, `bgsas-{env}-iac-terraform-state-{proyecto}`, con configuración inyectada vía `-backend-config` en la ejecución local.
- **Cifrado:** KMS CMK dedicada por servicio. Sin acceso público en cómputo ni datos.
- **Dimensionamiento por ambiente:** dev reducido (instancias pequeñas, 1 AZ de cómputo), qa intermedio, prod completo (3 AZs, HA).

Para los detalles de cada práctica, ver los archivos de *steering* de cada solución (`create-module`, `create-layer`, `use-module`, `naming-conventions`, `security`, `environment-config`).

---

## Operación (patrón común)

Cada layer se despliega de forma local con Terraform. Sustituye `{proyecto}`, `{env}` y `<layer>` según corresponda:

```bash
cd "<solución>/layers/<layer>"

terraform init \
  -backend-config="bucket=bgsas-{env}-iac-terraform-state-{proyecto}" \
  -backend-config="key=<layer>/terraform.tfstate" \
  -backend-config="region=us-west-2" \
  -input=false -reconfigure

terraform plan  -var-file=../environment/{env}/<layer>/{env}.tfvars -input=false
terraform apply -var-file=../environment/{env}/<layer>/{env}.tfvars -input=false
```

El orden de despliegue entre layers está documentado en el README de cada solución.

---

## Costos

Resumen de costos mensuales estimados en producción (us-west-2, On-Demand, sin descuentos por compromiso):

| Solución | prod | prod +50% |
|----------|-----:|----------:|
| Core Bancario | $2,009 | $3,061 |
| Gestión Administrativa (AGAT) | $1,419 | $2,567 |
| Procesamiento Tiempo Real (RTDA) | $1,929 | $2,820 |
| **Total** | **$5,357/mes** | **$8,448/mes** |

El análisis completo —desglose por servicio, supuestos, comparativa, proyección a 2 años y recomendaciones de optimización— está en **[`Estimacion_Costos_AWS_Consolidada.md`](./Estimacion_Costos_AWS_Consolidada.md)**. Cada solución incluye además sus propios CSV de estimación por ambiente.

---

*Mantenido por el área de Soluciones Digitales. Documentación en español; descripciones internas de módulos en inglés.*
