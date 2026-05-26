# `storages_principales.md`

# Storages Principales

La arquitectura contará con dos storages principales por cliente:

1. `MESSAGING_STORAGE`
2. `MULTIMEDIA_STORAGE`

Cada cliente tendrá recursos dedicados y aislados.

---

# 1. MESSAGING_STORAGE

Storage orientado al intercambio de mensajería, eventos y comandos dentro de la arquitectura desacoplada `pub/sub`.

Cada cliente contará con su propio storage dedicado.

---

## Objetivos

Este storage será utilizado para:

* Intercambio transaccional de eventos y comandos
* Persistencia temporal de paquetes de trabajo
* Generación de históricos y reportes
* Analítica
* Auditoría
* DRP (*Disaster Recovery Plan*)
* Compresión y archivado

---

# Componentes

## 1.1 Live Queue

Representa la estructura operativa viva de procesamiento.

Los archivos almacenados son paquetes JSON concretos de trabajo.

---

## Estructura

```txt id="lb4mwo"
/active/
    todo/
        outbound/
        inbound/
            status/
            message/

    in_process/
        outbound/
        inbound/
            status/
            message/

done/
    outbound/
    inbound/
        status/
        message/

error/
    outbound/
    inbound/
        status/
        message/
```

---

## Descripción de estados

| Ruta            | Descripción                           |
| --------------- | ------------------------------------- |
| `/todo`         | Eventos pendientes de procesamiento   |
| `/in_process`   | Eventos actualmente siendo procesados |
| `/done/`       | Eventos procesados exitosamente       |
| `/error/`        | Eventos procesados con error          |

---

# Estructura Alterna para Campañas

Los mensajes relacionados con campañas tendrán una estructura secundaria de acceso rápido que virtualizan apuntamiento a los JSON de la _live_queue_.

---

## Estructura

```txt id="s3v2bn"
/campaign/{channel_provider}/{channel_identifier}/{campaign_id}
```

---

# 1.2 Archivos Resumen

Archivos orientados a consulta histórica, reportería y analítica.

Formato recomendado: `parquet`.

---

## Estructura

```txt id="pk7q5u"
/data/{channel_provider}/{channel_identifier}/YYYYMMDD.parquet
```

---

## Objetivos

* Consultas analíticas
* Agregaciones rápidas
* KPIs
* Exportación de reportes
* Consumo por motores analíticos

---

# 1.3 Archivos Comprimidos

Archivos orientados a auditoría, respaldo y recuperación.

Formato recomendado:

* `jsonl.gz`

---

## Estructura

```txt id="q32w8l"
/archive/{channel_provider}/{channel_identifier}/YYYYMMDD.jsonl.gz
```

---

## Objetivos

* Auditoría histórica
* DRP
* Retención de largo plazo
* Reprocesamiento offline

---

# 2. MULTIMEDIA_STORAGE

Storage dedicado exclusivamente al almacenamiento multimedia del dominio del cliente.

---

## Características

| Característica   | Descripción                                                         |
| ---------------- | ------------------------------------------------------------------- |
| Storage dedicado | Cada cliente tendrá su propio bucket/storage                        |
| Tamaño máximo    | `XX MB` por archivo                                                 |
| Integridad       | Todos los archivos deben almacenar hash de validación como metadata |
| Seguridad        | La estructura debe permitir permisos dinámicos por conversación     |

---

## Objetivos

Este storage contendrá:

* Archivos multimedia enviados
* Archivos multimedia recibidos
* Assets de plantillas
* Assets de respuestas rápidas
* Assets de flows

---

# Reglas de Integridad

Todos los archivos deberán almacenar metadata de hash para garantizar:

* No modificación
* Validación de integridad
* Verificación de duplicados
* Control de versiones

---

# Estructura de Storage

---

## 2.1 Archivos de Catálogo

Assets reutilizables globales del cliente.

---

### Estructura

```txt id="l0r3od"
/catalog_files/{file_name}-{hash}.{ext}
```

---

## 2.2 Archivos Conversacionales

Assets asociados directamente a una conversación específica.

La estructura debe conservar el `vm_conv_id`.

---

### Estructura

```txt id="lq8t4e"
/conversational_files/{vm_conv_id}/{file_name}-{hash}.{ext}
```

---

# Consideraciones de Seguridad

La estructura basada en `vm_conv_id` es requerida para soportar:

* Permisos dinámicos de acceso
* Expiración de acceso
* Segmentación por conversación
* Auditoría por contacto
* Restricciones multi-tenant

---

# Recomendaciones Técnicas

| Componente      | Recomendación                       |
| --------------- | ----------------------------------- |
| Live Queue      | Objetos JSON pequeños               |
| Summary Data    | Formato Parquet                     |
| Archive         | JSON Lines comprimido (`jsonl.gz`)  |
| Media Hash      | SHA-256                             |
| Storage Backend | GCP Bucket Compatible                       |
| Permisos        | Dinámico basado en conversación |
| Compresión      | GZIP                                |
| Naming          | UTC-0 obligatorio                   |
