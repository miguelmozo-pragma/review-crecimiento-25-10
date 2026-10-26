## Objetivo de negocio

Proveer capacidades avanzadas de análisis para el procesamiento de datos en tiempo real, incluyendo la detección de fraudes y análisis de comportamiento de clientes.

## Descripción del requerimiento

- **Arquitectura Requerida:**
    - **Ingesta de datos:** Recibir datos en tiempo real desde diversas fuentes (transacciones, eventos, sensores, etc.).
    - **Procesamiento y análisis:** Utilizar una arquitectura de procesamiento en tiempo real con baja latencia.
    - **Almacenamiento:**
        - **Implementar un Data Lake o Data Warehouse** para análisis de grandes volúmenes de datos.
        - **Asegurar que los datos sean cifrados y accesibles** sólo para usuarios autorizados.
    - **Visualización y reporting:** Proveer herramientas de dashboarding para analistas de datos

### Solución propuesta

Se plantea una solución para el procesamiento y análisis en tiempo real en tres etapas (ingesta, Procesamiento y consumo). Para la ingesta de datos en tiempo real se va a  aprovisionar un nuevo data stream en kinesis, de igual forma se va a crear un firehose stream para enviar los datos ingestados por kinesis hacia un bucket de s3. Para el procesamiento de los datos ingestados en tiempo real se va a crear una nujeva aplicación en Amazon Managed service for apache flink la cual a su vez invocará el servicio de AWS Fraud detector para la detección de fraudes. Para el  consumo de los datos se tendrá por un lado una función lambda encargada de generar un nuevo evento en caso que se encuentre un fraude y ese evento será procesado por la capa de aplicación del core bancario, de igual forma, también se enviará una notificación del fraude usando un topico de SNS. 

## Listado recursos a Implementar (pendiente arq)

- Kinesis data stream
    - kms key
- Firehose stream
- S3 bucket
    - kms key
- Lake formation
    - Catalogs
    - Daatabases
    - Data permisions
- Amazon Managed service for apache flink application
- Detector (Fraud Detector)
    - s3 bucket y llave kms
    - rol del servicio
    - Cloudwatch logs, metrics alarms
    - Define models, variables, labels, eventType, outcome, rules, etc.
- Lambda function (Generar QR)
    - Rol para la lambda.
    - pipeline ajuste cod lambda
    - Cloudwatch resources (alarms, metrics, dashboard inclussion)
- SNS topic