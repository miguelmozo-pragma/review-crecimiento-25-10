# Product: Core Bancario Banca global S.A.S.

Infrastructure as Code repository for **Core Bancario** of Banca Global S.A.S. Manages all AWS infrastructure required to run the POS services platform across three environments: dev, qa (calidad), and prod.

## Objetivo de negocio

Modernizar y migrar el ecosistema de aplicaciones contenerizadas hacia una arquitectura *cloud-native* resiliente, garantizando la continuidad operativa con tiempo de inactividad cercano a cero, optimizando el costo total de propiedad (TCO/OpEx) y asegurando previsibilidad financiera mediante un plan de adopción técnica y económica integral. 

## Descripción del requerimiento

### Solución propuesta

#### Carga migrada (recursos persistentes)

Migrar la infraestructura hacia AWS con una estrategia de replatform. Para esto  en primer lugar se va a exponer las aplicaciones al publico (solo el modulo de estado de cuentas y el frontend) a traves de una distribución de Cloudfront. Para los diferentes modulos y aplicativos se va a hacer el despliegue de cada uno de los módulos (Módulo administrativo, módulo de créditos, Módulo de recaudo, Módulo inversiones, Módulo estado de cuentas) dentro de eks, como una combinación de varios recursos a nivel de kubernetes (service, deployment, service account, config map) en tres namespaces (frontend, public access(solo estado de cuentas), Administrative Access). para recibir y balancear el tráfico hacia los diferentes módulos se tendrán dos distintos ALBs, uno que estará conectado al cloudfront (para acceso público) a través de un vpc origin, y otro que será consultado directamente por usuarios administrativos de forma privada (usando una vpn site to site hacia las sedes). Para la persistencia de los datos se tendrá una base de datos aurora postgreSQL con una write y una read replica (read rep solo para prod y QA). De igual forma, para la persistencia de archivos y objetos se tendrá un bucket de s3. Finalmente también se aprovisionará una cache (elasticache) Redis. 

#### Migración (solo el primer mes o lo que dure la migración)

Se va a hacer uso de DMS para la migración de las diferentes vms de bases de datos (1 por ambiente) desde el servidor postgres on prem hacia el servicio de aurora PostgresQL. Para la migración del servidor FTP se va a hacer uso de datasync para migrar los datos hacia s3. Como las cargas ya están contenerizadas no va a ser necesario servicios adicionales simplemente mover las imagenes de contenedor hacia ECR o volverlas a construir directamente y pushearlas a ECR.

## Listado de recursos a crear

### Carga migrada (recursos persistentes)

- Recurso de red
    - vpc
    - subnets privadas
    - route tables
- Cluster eks
    - addon alb controler
- Modulo frontend
    - service
    - deployment
    - ECR repo
    - sg
    - Role
    - Service account con RBAC
    - pipeline despliegue de Codigo
    - namespace public access
    - Ingress
- Modulo estado de cuentas
    - service
    - deployment
    - ECR repo
    - sg
    - Role
    - Service account con RBAC
    - pipeline despliegue de Codigo
    - namespace public access
    - Ingress
- Modulo creditos
    - service
    - deployment
    - ECR repo
    - sg
    - Role
    - Service account con RBAC
    - pipeline despliegue de Codigo
    - namespace Administrative access
    - Ingress
- Modulo Recaudo
    - service
    - deployment
    - ECR repo
    - sg
    - Role
    - Service account con RBAC
    - pipeline despliegue de Codigo
    - Ingress
- Modulo Inversiones
    - service
    - deployment
    - ECR repo
    - sg
    - Role
    - Service account con RBAC
    - pipeline despliegue de Codigo
    - Ingress
- Modulo Administrativo
    - service
    - deployment
    - ECR repo
    - sg
    - Role
    - Service account con RBAC
    - pipeline despliegue de Codigo
    - Ingress
- Cloudfront distribution
    - acm certificate.
    - vpc origin to alb
- Aurora postgresQL cluster
    - db instance writer.
    - db instance reader.
    - kms key
    - Secret credentials
    - sgs.
- Elasticache Redis
    - kms key
- S3 bucket
    - kms key
    - vpc endpoint para acceso desde servicios en la vpc

### Migración (solo el primer mes o lo que dure la migración)

- DMS
    - DMS Replication instance
    - DMS endpoints (source, target)
    - DMS replication task
    - kms key
    - secret credenciales de conexión
    - sg instance
- Datasync
    - vpc endpoint para migración con datasync
    - sg.

### Consideraciones dimensionamiento cada ambiente

- 3 azs para prod y QA, 1 AZ para DEV
- 3 pods por deployment para prod, 3 pods por deployment QA, 1 pod por deployment dev
- 1024 MB de memoria y 512 mcpu para cada pod en prod, 512 MB memoria y 256mcpu para pods en QA y dev.
- Instancias de bbdd grande para Prod con writer y reader instance para Prod, Instancias de bbdd mediana para  con writer y reader instance para QA, y una sola instancia de escritura para dev lo más pequeña posible.
- Elasticache grande para prod, mediana para QA y pequeña para dev.
- DMS con instancia grande para prod, mediana para QA y pequeña para dev.

## Preguntas para cliente

- Cual es el RPO y el RTO esperado para el ambiente productivo?
- Cual es el volumen de datos que pueden mover en la migración?
- Migración puede ser conectada por red a AWS o Se necesita migrar los datos directamente del data center
- puden compartir el tamaño de cada uno de los servidores físicos, de las VMS y de los contenedores usados por los microservicios  (cpu, memoria, disco)?