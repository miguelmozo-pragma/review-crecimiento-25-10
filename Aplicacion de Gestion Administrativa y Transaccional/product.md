# Product: Aplicación de gestión administrativa y transaccional Banca global S.A.S. 

Infrastructure as Code repository for **Aplicación de gestión administrativa** for Banca Global S.A.S. Manages all AWS infrastructure required to run the POS services platform across three environments: dev, qa (calidad), and prod.
## Objetivo de Negocio

Una aplicación que permita a Banca Global gestionar cuentas de clientes, autorizaciones de pagos y la administración interna

## Descripción del requerimiento

- **Arquitectura de 3 capas:**
    - Front-end: Aplicación web responsiva y segura para usuarios internos y clientes.
    - Back-end: Microservicios que gestionen la lógica de negocio, autenticación y autorización.
    - Persistencia de datos: Bases de datos relacionales con alta disponibilidad y escalabilidad.
- **Seguridad:**
    - Implementar un modelo de autenticación robusto con MFA y gestión de identidades.
    - Asegurar cifrado de datos en tránsito y en reposo.
    - Proteger el perímetro utilizando firewalls, WAF y protección contra ataques DDoS.
- **Alta disponibilidad y resiliencia:**
    - Diseñar para soportar failover automático y recuperación ante desastres.

### Solucion propuesta.

Un cluster de EKS para soportar el frontend y el backend de esta nueva aplicación, y para la persistencia de los datos una base de datos en aurora PostgreSQL, los servicios van a ser expuestos de forma interna usando un internal ALB (Ingress). Cuando necesiten hacer la autorización y autenticación de los usuarios las apps en eks podrán salir a consultar el external idp a través de la cuenta de Networking. 

## Listado de componentes a crear (Por definir arquitectura)

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
- Modulo Backend
    - service
    - deployment
    - ECR repo
    - sg
    - Role
    - Service account con RBAC
    - pipeline despliegue de Codigo
    - namespace public access
    - Ingress
- Aurora postgresQL cluster
    - db instance writer.
    - db instance reader.
    - kms key
    - Secret credentials
    - sgs.

### Consideraciones dimensionamiento cada ambiente

- 3 azs para prod y QA, 1 AZ para DEV
- 3 pods por deployment para prod, 3 pods por deployment QA, 1 pod por deployment dev
- 1024 MB de memoria y 512 mcpu para cada pod en prod, 512 MB memoria y 256mcpu para pods en QA y dev.
- Instancias de bbdd grande para Prod con writer y reader instance para Prod, Instancias de bbdd mediana para  con writer y reader instance para QA, y una sola instancia de escritura para dev lo más pequeña posible.