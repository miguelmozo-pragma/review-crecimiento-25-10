# Estimación de Costos AWS — Banca Global S.A.S.
## Análisis consolidado de tres soluciones (perspectiva CloudOps)

**Región:** us-west-2 (Oregon) · **Moneda:** USD · **Modelo:** On-Demand, sin free tier, sin Savings Plans/RI.
**Fuente de precios:** tarifas oficiales vigentes de AWS, con cálculo por componente.
**Alcance:** tres soluciones independientes, cada una con ambientes dev / qa / prod y un escenario de crecimiento (prod +50%).

> Las cifras son estimaciones de planeación (capacity planning), no una factura garantizada. El gasto real depende del consumo efectivo (autoscaling, tráfico, retención), de descuentos por compromiso (Savings Plans / Reserved Instances) y del free tier, ninguno de los cuales se aplica aquí deliberadamente para obtener una **cota superior conservadora**.

---

## 1. Resumen ejecutivo

| Solución | dev | qa | prod | prod +50% | prod anual |
|----------|----:|---:|-----:|----------:|-----------:|
| **Core Bancario** (EKS + Aurora + Redis + CloudFront + migración) | $565 | $1,213 | **$2,009** | $3,061 | $24,105 |
| **Gestión Administrativa (AGAT)** (EKS + Aurora, interno) | $242 | $779 | **$1,419** | $2,567 | $17,029 |
| **Procesamiento Tiempo Real (RTDA)** (Kinesis + Flink + Fraud Detector) | $334 | $818 | **$1,929** | $2,820 | $23,150 |
| **TOTAL prod (3 soluciones)** | | | **$5,357/mes** | | **$64,285/año** |

Costo mensual aproximado si los **tres ambientes de las tres soluciones** corrieran en paralelo: **~$10,310/mes**. En la práctica, dev y qa suelen apagarse fuera de horario, por lo que el gasto efectivo es menor.

**Conclusión de alto nivel:** las tres soluciones quedan en el mismo orden de magnitud en producción ($1,400–$2,000/mes), lo cual es sano: ninguna domina el presupuesto de forma desproporcionada. El driver de costo en cada una es distinto y se explica más abajo.

---

## 2. Metodología y criterios

Cada ambiente se modeló a partir de la infraestructura **realmente desplegable** (los módulos y variables de Terraform de cada solución), no de un diseño idealizado. Los criterios de modelado más importantes:

1. **Un modelo por ambiente, no multi-cuenta simultánea.** Cada solución se estima por ambiente (dev, qa, prod) de forma independiente, tal como se despliega: ambientes separados en la misma cuenta y región. No se suman cuentas corriendo en paralelo salvo donde se indica explícitamente.

2. **Sin doble conteo de cómputo en EKS.** Los pods de los microservicios corren **sobre los worker nodes EC2** gestionados por Karpenter. Se contabiliza el costo de los nodos dimensionados a la carga real de pods, no el cómputo de los pods por separado.

3. **Dimensionamiento diferenciado por ambiente.** dev/qa/prod no son el mismo modelo escalado por un porcentaje: usan clases de instancia distintas (t4g/t3 pequeñas en dev, r6g grandes en prod), número de AZs distinto y feature flags distintos (pipelines on/off). Cada ambiente se estimó con su propio set de supuestos.

Este nivel de rigor es lo que separa una estimación defendible de un número inflado. Un número inflado erosiona la confianza del negocio y lleva a sobredimensionar; uno demasiado optimista provoca sorpresas en la factura.

---

## 3. Core Bancario — migración a EKS

### Arquitectura
Plataforma *cloud-native* en EKS: 6 microservicios (frontend, estado-cuentas, créditos, recaudo, inversiones, administrativo), expuestos vía CloudFront → ALB interno (VPC Origin) y un ALB administrativo privado. Persistencia en Aurora PostgreSQL (writer + reader), caché ElastiCache Redis, almacenamiento S3, y una capa de migración temporal (DMS + DataSync) desde el on-premise.

### Desglose de producción ($2,009/mes)

| Servicio | $/mes | Comentario |
|----------|------:|------------|
| Aurora writer (r6g.xlarge) | $503 | Base de datos transaccional |
| Aurora reader (r6g.xlarge) | $503 | Réplica de lectura (HA + offload) |
| EKS worker nodes (4× t3.large) | $285 | 18 pods (6 micros × 3) + addons |
| **DMS (temporal)** | $241 | Solo durante la migración |
| CloudWatch Logs | $75 | |
| EKS control plane | $73 | Tarifa fija $0.10/h |
| CloudFront + ALBs | $111 | Exposición del portal |
| Resto (KMS, S3, DT, VPC, pipelines) | $218 | |

### Supuestos y justificación
- **Aurora es el 50% del costo.** Es coherente: es un core bancario, la base de datos es el activo crítico y se dimensiona para rendimiento y alta disponibilidad (writer + reader en r6g.xlarge). En el mundo real, esta es exactamente la partida donde **no se escatima** y donde un Reserved Instance de 1 año reduciría ~30-40%.
- **DMS es temporal (~$241/mes).** Solo corre durante la ventana de migración. El costo *permanente* de prod post-migración es **~$1,768/mes**. Documentarlo evita que se perciba como gasto recurrente.
- **Karpenter sobre nodos EC2.** Se modeló una base de 4× t3.large para alojar los 18 pods de carga más los addons de sistema (CoreDNS, LB Controller, EBS CSI, el propio Karpenter). Es un supuesto conservador; con consolidación spot el costo real suele ser menor.

---

## 4. Gestión Administrativa y Transaccional (AGAT)

### Arquitectura
Aplicación de 3 capas sobre EKS: 2 microservicios (frontend, backend), expuestos **solo internamente** vía ALB (sin CloudFront). Persistencia en Aurora PostgreSQL (writer + reader). Autenticación contra un IdP externo alcanzado a través de la cuenta de Networking.

### Desglose de producción ($1,419/mes)

| Servicio | $/mes | Comentario |
|----------|------:|------------|
| Aurora writer (r6g.xlarge) | $503 | |
| Aurora reader (r6g.xlarge) | $503 | |
| EKS worker nodes (2× t3.large) | $133 | 6 pods (2 micros × 3) + addons |
| EKS control plane | $73 | |
| CloudWatch Logs | $60 | |
| ALB interno | $34 | Sin CloudFront (todo privado) |
| Resto | $113 | |

### Supuestos y justificación
- **Es la solución más económica** ($1,419 vs $2,009 del core) por ser estructuralmente más simple: 2 microservicios en vez de 6, sin Redis, sin S3 de objetos, sin CloudFront y sin capa de migración. La mitad de worker nodes (6 pods vs 18).
- **Mismo tamaño de Aurora que el core.** Aunque la app es más chica, se mantuvo r6g.xlarge writer+reader porque es la misma clase de dato sensible (cuentas, autorizaciones de pago) y la organización ya estandarizó esa línea base. Si el volumen transaccional fuera notablemente menor, bajar a r6g.large ahorraría ~$500/mes.
- **Exposición interna** reduce superficie de ataque y elimina el costo de CloudFront/WAF que sí tiene el portal del core.

---

## 5. Procesamiento y Análisis en Tiempo Real (RTDA)

### Arquitectura
Pipeline serverless de streaming en tres etapas: **ingesta** (Kinesis Data Stream → Firehose → S3), **procesamiento** (Managed Service for Apache Flink → AWS Fraud Detector), **consumo** (Lambda genera evento de fraude + SNS notifica). Data Lake en S3 gobernado con Lake Formation.

### Desglose de producción ($1,929/mes — supuesto optimizado)

| Servicio | $/mes | Comentario |
|----------|------:|------------|
| **Fraud Detector ML** (10k pred.) | $750 | Solo casos sospechosos |
| **Fraud Detector reglas** (90k pred.) | $675 | Pre-clasificación barata |
| Flink (4 KPU) | $326 | Procesamiento continuo |
| CloudWatch Logs | $50 | |
| S3 (raw + data lake) | $38 | |
| Kinesis + Firehose | $58 | Ingesta |
| Resto (KMS, DT, Lambda, SNS) | $32 | |
| Lake Formation | $0 | Sin cargo directo |

### El hallazgo central: Fraud Detector es el driver de costo
Este es el caso donde **el supuesto de arquitectura cambia el costo en un orden de magnitud**:

| Supuesto de volumen a Fraud Detector | Costo prod/mes |
|--------------------------------------|---------------:|
| 100% de transacciones (1M, modelo inicial) | **$11,954** |
| Solo 10% tras pre-filtro en Flink (100k) | **$1,929** |

Enviar cada transacción al detector de fraude ML cuesta ~$0.075 c/u; a 1M/mes eso solo son $75k... la realidad de negocio es que **no todas las transacciones necesitan análisis ML**. Lo correcto —y lo que hace cualquier arquitectura de fraude madura— es un **pre-filtro de reglas en Flink** que descarta el ~90% de las transacciones evidentemente legítimas antes de invocar el modelo. Con ese patrón:
- 90% se descarta en Flink (costo marginal ~$0).
- 9% pasa por reglas de Fraud Detector ($0.0075 c/u).
- 1% (lo verdaderamente sospechoso) va al modelo ML ($0.075 c/u).

Esto reduce el costo de prod **de $11,954 a $1,929 (−84%)** sin degradar la capacidad de detección, siempre que las reglas de pre-filtrado estén bien calibradas.

### Supuestos y justificación
- **El pipeline de datos es barato (~$500/mes).** Kinesis, Firehose, S3, Flink y Lake Formation juntos cuestan menos que una sola instancia Aurora. El valor (y el costo) de esta solución está en la **inteligencia de fraude**, no en mover datos.
- **Trade-off a vigilar:** un pre-filtro agresivo que descarte el 90% puede dejar pasar fraude si las reglas son pobres. El balance óptimo entre costo de predicción y costo de un falso negativo (fraude no detectado) es una decisión de negocio, no solo técnica. La arquitectura justifica invertir en buenas reglas de Flink.
- **Lake Formation no tiene cargo directo:** el gobierno de datos es gratis; los costos subyacentes (Glue, S3, consultas Athena) se facturan por esos servicios.
- **Fraud Detector usa precios escalonados (tiered):** las predicciones ML cuestan más en los primeros tramos y bajan con volumen; el modelo aplica las tarifas por tramo documentadas por AWS.

---

## 6. Comparativa y lectura transversal

### Driver de costo por solución

| Solución | Driver principal | % del prod |
|----------|------------------|-----------:|
| Core Bancario | Aurora (writer + reader) | ~50% |
| AGAT | Aurora (writer + reader) | ~71% |
| RTDA | Fraud Detector (ML + reglas) | ~74% |

**Patrón:** en las soluciones transaccionales el costo lo manda la **base de datos**; en la de analítica lo manda el **servicio de inferencia (fraude)**. En ambos casos, el cómputo (EKS/Flink) y el movimiento de datos son secundarios. Esto orienta dónde concentrar los esfuerzos de optimización.

### Crecimiento (prod → prod +50%)

| Solución | prod | +50% | incremento |
|----------|-----:|-----:|-----------:|
| Core Bancario | $2,009 | $3,061 | +52% |
| AGAT | $1,419 | $2,567 | +81% |
| RTDA | $1,929 | $2,820 | +46% |

El crecimiento no es lineal ni uniforme: AGAT escala más caro proporcionalmente porque el salto de Aurora al siguiente tier (r6g.xlarge → 2xlarge) duplica el costo de la partida dominante. Donde el +50% busca *throughput* más que *tamaño*, suele ser más barato **escalar horizontalmente** (más réplicas de lectura) que verticalmente (instancia más grande).

---

## 7. Proyección a dos años (escenario de crecimiento prod +50%)

Esta proyección asume que las tres soluciones alcanzan el nivel de carga **prod +50%** y se mantienen en operación durante 24 meses. Representa el escenario de régimen tras consolidar la adopción y absorber el crecimiento esperado de la plataforma.

### Costo mensual en régimen (prod +50%)

| Solución | prod +50% / mes |
|----------|----------------:|
| Core Bancario | $3,061 |
| Gestión Administrativa (AGAT) | $2,567 |
| Procesamiento Tiempo Real (RTDA) | $2,820 |
| **Total mensual** | **$8,448** |

### Proyección acumulada a 24 meses (On-Demand, sin descuentos)

| Horizonte | Core Bancario | AGAT | RTDA | **Total** |
|-----------|-------------:|-----:|-----:|----------:|
| Mensual | $3,061 | $2,567 | $2,820 | **$8,448** |
| Año 1 (12 meses) | $36,732 | $30,799 | $33,843 | **$101,374** |
| Año 2 (12 meses) | $36,732 | $30,799 | $33,843 | **$101,374** |
| **Total 2 años** | **$73,464** | **$61,608** | **$67,686** | **$202,758** |

### Proyección a 24 meses con optimización (Savings Plans / RI)

Las partidas fijas y predecibles (Aurora, control plane y nodos base de EKS, Flink) son candidatas a compromiso de 1-3 años. Asumiendo un **ahorro conservador del 30%** sobre el cómputo y bases de datos comprometibles —aproximadamente el 70% del gasto total—, el efecto neto sobre el total es cercano a un **−21%**:

| Horizonte | Total On-Demand | Total optimizado (~−21%) | Ahorro |
|-----------|----------------:|-------------------------:|-------:|
| Mensual | $8,448 | ~$6,674 | ~$1,774 |
| **Total 2 años** | **$202,758** | **~$160,180** | **~$42,578** |

### Consideraciones de la proyección
- **Costo plano año a año:** la proyección asume carga estable en prod +50%; no modela crecimiento adicional más allá de ese nivel. Si la carga sigue creciendo, el gasto subiría proporcionalmente al driver de cada solución (Aurora en las transaccionales, volumen de predicciones en RTDA).
- **No incluye inflación de precios de AWS** ni nuevos servicios. AWS tiende a reducir precios con el tiempo, pero conviene presupuestar con las tarifas actuales.
- **El escenario optimizado requiere compromiso financiero anticipado** (Savings Plans de 1 o 3 años). Es la decisión de mayor impacto económico y debería tomarse una vez que la carga de prod se estabilice (típicamente tras el primer trimestre).
- **Dev y qa no están en esta proyección de régimen:** se asume que operan bajo demanda / horario laboral y no al nivel prod +50%. Incluirlos continuamente añadiría del orden de $1,800-2,000/mes adicionales.

---

## 8. Recomendaciones de optimización (CloudOps)

1. **Savings Plans / Reserved Instances para Aurora y EKS en prod.** Las partidas fijas y predecibles (Aurora, control plane EKS, nodos base) son candidatas ideales. Un compromiso de 1 año reduce ~30-40% esas líneas, el mayor ahorro individual disponible.
2. **Apagar dev/qa fuera de horario laboral.** dev y qa no necesitan correr 24/7. Un apagado nocturno/fin de semana (~65% de las horas) reduce su costo de cómputo proporcionalmente — relevante porque entre los tres proyectos, dev+qa suman ~$3,950/mes.
3. **Pre-filtro de fraude bien calibrado (RTDA).** Es la palanca de mayor impacto: cada punto porcentual de transacciones que se evita enviar a Fraud Detector ML ahorra proporcionalmente. Mantener el ratio de ML lo más bajo posible sin perder cobertura de fraude.
4. **Retirar DMS/DataSync al cerrar la migración (Core Bancario).** Son ~$250/mes temporales; destruir esa capa al terminar la migración es un ahorro inmediato y una buena práctica de higiene (no dejar infraestructura temporal corriendo).
5. **Revisar el dimensionamiento de Aurora contra el uso real** tras 1-2 meses en producción. Es común sobredimensionar al inicio; Aurora permite escalar la clase sin downtime significativo, así que conviene empezar conservador y ajustar con datos reales de CPU/conexiones.
6. **Graviton (r6g/t4g) ya está en uso** en Aurora, Redis y parte del cómputo — buena decisión, es ~20% más barato que las clases Intel equivalentes. Extenderlo a los worker nodes EKS (instancias `m7g`/`c7g`) daría ahorro adicional.

---

## 9. Supuestos globales y limitaciones

- **Sin free tier ni descuentos por compromiso:** las cifras son una cota superior. El gasto real con Savings Plans y free tier será menor.
- **Carga normalizada:** 1M transacciones/mes para las soluciones transaccionales; dev al ~15% y qa al ~40% de esa referencia, ajustado además por clase de instancia real.
- **Precios puntuales:** tarifas oficiales de AWS vigentes al momento de la estimación. AWS ajusta precios periódicamente; conviene revalidar trimestralmente.
- **Red:** en dev se modelan 2 AZs (no 1) porque los subnet groups de Aurora/EKS/ElastiCache exigen un mínimo de dos zonas, aunque el cómputo use una sola.
- **No incluye:** soporte AWS (Business/Enterprise), transferencia inter-región (no hay multi-región), ni costos de observabilidad de terceros.

---

*Documento preparado para el ejercicio de planeación de costos de Banca Global S.A.S. — área de Soluciones Digitales. Las estimaciones deben revalidarse contra el consumo real tras el primer trimestre en producción.*
