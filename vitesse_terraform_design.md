# Vitesse v11 — Diseño de Infraestructura GCP con Terraform

> **Plataforma:** WhatsApp Messaging Platform · **Versión de arquitectura:** v11 · **Fecha:** Mayo 2026

---

## Tabla de Contenido

1. [Visión General](#1-visión-general)
2. [Principios de Diseño](#2-principios-de-diseño)
3. [Estrategia de Ambientes](#3-estrategia-de-ambientes)
4. [Convención de Nomenclatura](#4-convención-de-nomenclatura)
5. [Arquitectura de Storage (Cloud Storage)](#5-arquitectura-de-storage)
6. [Backbone Transaccional (Pub/Sub)](#6-backbone-transaccional-pubsub)
7. [Proyección Viva (Firestore)](#7-proyección-viva-firestore)
8. [Estrategia IAM y Seguridad](#8-estrategia-iam-y-seguridad)
9. [Estructura de Módulos Terraform](#9-estructura-de-módulos-terraform)
10. [Diagramas de Despliegue](#10-diagramas-de-despliegue)
11. [Guía de Despliegue](#11-guía-de-despliegue)

---

## 1. Visión General

Vitesse v11 es una plataforma de mensajería multicanal (WhatsApp, Instagram, Messenger) sobre GCP.
La arquitectura elimina Cloud SQL del hot path operativo y lo reemplaza con tres capas especializadas:

| Capa | Servicio GCP | Responsabilidad principal |
|------|-------------|--------------------------|
| Event Log | Cloud Storage | Registro inmutable de eventos — `/active`, `/archived`, `/data` |
| Backbone Transaccional | Cloud Pub/Sub | Desacoplamiento, buffering, reintentos y DLQ entre todos los componentes |
| Proyección Viva | Firestore (Native) | Índices de correlación y vista viva para el frontend sin polling |

**Regla de diseño core:** Ningún componente de negocio invoca a otro directamente. Todo evento operativo —outbound, inbound, status, media, maintenance— pasa primero por Pub/Sub.

---

## 2. Principios de Diseño

| Principio | Decisión | Resultado |
|-----------|----------|-----------|
| Conversación como entidad raíz | `vitesse_msg_id` es la raíz de conversación | Todos los gsId/wamid se correlacionan contra un mismo hilo |
| Event log barato | `/active` + `/archived` + `/data` en Cloud Storage | Replay, compresión, auditoría y analítica sin saturar la BD |
| Lookup rápido | Firestore para índices y proyección viva | Frontend y correlación sin listar objetos en Storage |
| Frontend por push | Firestore + push desde backend | No polling, menor latencia visible |
| Campaign siempre presente | `campaign_id` real o sintético mensual (`organic_YYYY_MM`) | Trazabilidad comercial completa |
| Multi-tenant estricto | Recursos dedicados en prod/preprod, prefijos en dev/staging | Aislamiento de datos por cliente |

---

## 3. Estrategia de Ambientes

### 3.1 Cuatro Ambientes

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VITESSE — TOPOLOGÍA DE AMBIENTES                  │
├──────────────────────────┬──────────────────────────────────────────┤
│   COMPARTIDOS            │   DEDICADOS POR CLIENTE                  │
│   (Dev / Staging)        │   (Preprod / Prod)                       │
├──────────────────────────┼──────────────────────────────────────────┤
│                          │                                          │
│  GCP Project             │  GCP Project                             │
│  vtss-dev / vtss-stg     │  vtss-preprod / vtss-prod               │
│                          │                                          │
│  ┌─────────────────┐     │  ┌──────────────┐  ┌──────────────┐    │
│  │  1 Bucket MSG   │     │  │Bucket MSG    │  │Bucket MSG    │    │
│  │  (compartido)   │     │  │cliente_001   │  │cliente_002   │    │
│  └─────────────────┘     │  └──────────────┘  └──────────────┘    │
│                          │                                          │
│  ┌─────────────────┐     │  ┌──────────────┐  ┌──────────────┐    │
│  │  1 Bucket MLT   │     │  │Bucket MLT    │  │Bucket MLT    │    │
│  │  (compartido)   │     │  │cliente_001   │  │cliente_002   │    │
│  └─────────────────┘     │  └──────────────┘  └──────────────┘    │
│                          │                                          │
│  ┌─────────────────┐     │  ┌──────────────┐  ┌──────────────┐    │
│  │  1 Firestore DB │     │  │Firestore DB  │  │Firestore DB  │    │
│  │  (prefijos por  │     │  │cliente_001   │  │cliente_002   │    │
│  │   cliente)      │     │  │(dedicada)    │  │(dedicada)    │    │
│  └─────────────────┘     │  └──────────────┘  └──────────────┘    │
│                          │                                          │
│  ┌─────────────────┐     │  ┌──────────────┐  ┌──────────────┐    │
│  │  Topics Pub/Sub │     │  │Topics Pub/Sub│  │Topics Pub/Sub│    │
│  │  (compartidos,  │     │  │cliente_001   │  │cliente_002   │    │
│  │  customer_id en │     │  │(dedicados)   │  │(dedicados)   │    │
│  │  atributos)     │     │  └──────────────┘  └──────────────┘    │
│  └─────────────────┘     │                                          │
└──────────────────────────┴──────────────────────────────────────────┘
```

### 3.2 Dev y Staging — Recursos Compartidos

- **Cloud Storage:** 1 bucket de mensajería + 1 bucket multimedia. El prefijo del objeto incluye el `customer_id` para separación lógica.
- **Firestore:** 1 base de datos compartida. Los nombres de colección llevan prefijo `{customer_id}_` (ej. `c001_conversations`).
- **Pub/Sub:** 1 conjunto de topics compartidos. El `customer_id` viaja como atributo del mensaje para routing.
- **IAM:** Cuentas de servicio compartidas por rol (no por cliente).
- **Propósito:** Desarrollo activo y pruebas de integración. Costo mínimo.

### 3.3 Preprod y Prod — Recursos Dedicados por Cliente

- **Cloud Storage:** 1 bucket de mensajería + 1 bucket multimedia **por cliente**. Sin mezcla de datos entre clientes.
- **Firestore:** 1 base de datos Native **por cliente** (Named Databases de GCP Firestore). TTL y reglas de seguridad independientes.
- **Pub/Sub:** 1 conjunto completo de topics + subscriptions + DLQs **por cliente**. Aislamiento de throughput y errores.
- **IAM:** Cuentas de servicio backend y frontend **por cliente**. Principio de mínimo privilegio estricto.
- **Propósito:** Preprod = validación de cliente con datos reales. Prod = producción.

---

## 4. Convención de Nomenclatura

### 4.1 Patrón General

```
vtss-{env}-{customer_id}-{sufijo}
```

Donde:
- `vtss` = prefijo fijo de la plataforma Vitesse
- `env` = `dev` | `stg` | `preprod` | `prod`
- `customer_id` = identificador alfanumérico del cliente (solo en preprod/prod)
- `sufijo` = tipo de recurso

### 4.2 Tabla de Nomenclatura por Recurso

| Recurso | Dev / Staging | Preprod / Prod |
|---------|--------------|----------------|
| Proyecto GCP | `vtss-dev` / `vtss-stg` | `vtss-preprod` / `vtss-prod` |
| Bucket Mensajería | `vtss-{env}-messaging` | `vtss-{env}-{cid}-msg` |
| Bucket Multimedia | `vtss-{env}-multimedia` | `vtss-{env}-{cid}-mlt` |
| Firestore Database | `vtss-{env}-db` | `vtss-{env}-{cid}-db` |
| Topic outbound-commands | `vtss-{env}-outbound-commands` | `vtss-{env}-{cid}-outbound-commands` |
| Topic inbound-events | `vtss-{env}-inbound-events` | `vtss-{env}-{cid}-inbound-events` |
| Topic status-events | `vtss-{env}-status-events` | `vtss-{env}-{cid}-status-events` |
| Topic projection-updates | `vtss-{env}-projection-updates` | `vtss-{env}-{cid}-projection-updates` |
| Topic maintenance-commands | `vtss-{env}-maintenance-commands` | `vtss-{env}-{cid}-maintenance-commands` |
| Topic media-commands | `vtss-{env}-media-commands` | `vtss-{env}-{cid}-media-commands` |
| DLQ Topic | `vtss-{env}-dlq-{topic}` | `vtss-{env}-{cid}-dlq-{topic}` |
| SA Backend cliente | N/A | `vtss-{env}-{cid}-be@{project}.iam...` |
| SA Frontend cliente | N/A | `vtss-{env}-{cid}-fe@{project}.iam...` |
| SA CRF Parser | `vtss-{env}-crf-parser@...` | `vtss-{env}-crf-parser@...` |
| SA CRF Receptor | `vtss-{env}-crf-receptor@...` | `vtss-{env}-crf-receptor@...` |
| SA CRF Sender | `vtss-{env}-crf-sender@...` | `vtss-{env}-crf-sender@...` |
| SA CRF Processor | `vtss-{env}-crf-processor@...` | `vtss-{env}-crf-processor@...` |
| SA CRF Media Handler | `vtss-{env}-crf-media@...` | `vtss-{env}-crf-media@...` |
| SA CRF Projector | `vtss-{env}-crf-projector@...` | `vtss-{env}-crf-projector@...` |
| SA Cloud Scheduler | `vtss-{env}-scheduler@...` | `vtss-{env}-scheduler@...` |

---

## 5. Arquitectura de Storage

### 5.1 MESSAGING_STORAGE — Estructura de Directorios

```
vtss-{env}-{cid}-msg/
│
├── active/
│   ├── todo/
│   │   ├── outbound/{app}/{YYYYMMDD}/{HH}/{campaign_id}/{vitesse_msg_id}/{event_ts}_{local_ref}.json
│   │   └── inbound/
│   │       ├── message/{app}/{YYYYMMDD}/{HH}/{campaign_id}/{vitesse_msg_id}/{event_ts}_{wamid}.json
│   │       └── status/{app}/{YYYYMMDD}/{HH}/{campaign_id}/{vitesse_msg_id}/{event_ts}_{gsId}_{status}.json
│   ├── in_process/
│   │   ├── outbound/...
│   │   └── inbound/{message,status}/...
│   ├── done/
│   │   ├── outbound/{app}/{YYYYMMDD}/{HH}/{campaign_id}/{vitesse_msg_id}/{event_ts}_{gsId}.json
│   │   └── inbound/{message,status}/...
│   └── error/
│       ├── outbound/...  ← DLQ agotado, sin ack del proveedor
│       └── inbound/{message,status}/...
│
├── archived/
│   └── {app}/{YYYYMMDD}.jsonl.gz   ← Compressor D-30 genera este archivo
│
├── data/
│   └── {app}/{YYYYMMDD}.parquet    ← Aggregator genera este archivo
│
├── campaign/
│   └── {channel_provider}/{channel_identifier}/{campaign_id}/
│       └── ... → symlinks/punteros al JSON en /active/
│
└── media/
    └── {app}/{YYYY}/{MM}/{hash}.{ext}   ← CRF Media Handler
```

### 5.2 MULTIMEDIA_STORAGE — Estructura de Directorios

```
vtss-{env}-{cid}-mlt/
│
├── catalog_files/
│   └── {file_name}-{hash}.{ext}    ← Assets reutilizables del cliente
│
└── conversational_files/
    └── {vm_conv_id}/
        └── {file_name}-{hash}.{ext}  ← Assets de conversaciones
```

### 5.3 Lifecycle Rules de Cloud Storage

| Prefijo | Acción | Condición |
|---------|--------|-----------|
| `active/done/` | Delete | age > 45 días |
| `active/error/` | Delete | age > 90 días |
| `active/in_process/` | Delete | age > 7 días (objetos huérfanos) |
| `archived/` | SetStorageClass → Nearline | age > 30 días |
| `archived/` | SetStorageClass → Coldline | age > 365 días |
| `data/` | SetStorageClass → Nearline | age > 30 días |
| `data/` | Delete | age > 730 días (2 años) |
| `media/` (multimedia) | SetStorageClass → Nearline | age > 90 días |

### 5.4 Dev/Staging — Separación por Prefijo de Objeto

En dev/staging, los objetos incluyen el `customer_id` como primer segmento de ruta:

```
active/todo/outbound/{customer_id}/{app}/{YYYYMMDD}/...
archived/{customer_id}/{app}/{YYYYMMDD}.jsonl.gz
data/{customer_id}/{app}/{YYYYMMDD}.parquet
```

---

## 6. Backbone Transaccional — Pub/Sub

### 6.1 Topología de Topics y Subscriptions

```
┌────────────────────────────────────────────────────────────────────────┐
│                    TOPOLOGÍA PUB/SUB — VITESSE v11                      │
├──────────────────┬──────────────────────────────────┬──────────────────┤
│   PRODUCTORES    │          TOPICS / DLQ            │   CONSUMIDORES   │
├──────────────────┼──────────────────────────────────┼──────────────────┤
│                  │                                  │                  │
│  CRF Parser  ───►│  outbound-commands               │►  CRF Sender     │
│  Campaign Loader │    └─ dlq-outbound               │                  │
│                  │                                  │                  │
│  CRF Receptor ──►│  inbound-events                  │►  CRF Processor  │
│                  │    └─ dlq-inbound                │                  │
│                  │                                  │                  │
│  CRF Receptor ──►│  status-events                   │►  CRF Processor  │
│  DLR             │    └─ dlq-status                 │  DLR             │
│                  │                                  │                  │
│  CRF Processor──►│  projection-updates              │►  CRF Projector  │
│                  │    └─ dlq-projection             │  (Firestore)     │
│                  │                                  │                  │
│  Cloud Scheduler►│  maintenance-commands            │►  Aggregator     │
│                  │    └─ dlq-maintenance            │►  Compressor     │
│                  │                                  │►  Cleanup Worker │
│                  │                                  │                  │
│  CRF Receptor ──►│  media-commands                  │►  CRF Media      │
│  CRF Processor   │    └─ dlq-media                 │  Handler         │
└──────────────────┴──────────────────────────────────┴──────────────────┘
```

### 6.2 Configuración de Topics

| Topic | Retención de mensajes | Max delivery attempts | Ack deadline |
|-------|----------------------|----------------------|--------------|
| outbound-commands | 7 días | 5 → DLQ | 60s |
| inbound-events | 7 días | 5 → DLQ | 30s |
| status-events | 7 días | 5 → DLQ | 30s |
| projection-updates | 3 días | 5 → DLQ | 30s |
| maintenance-commands | 1 día | 3 → DLQ | 120s |
| media-commands | 3 días | 5 → DLQ | 120s |
| DLQ (todos) | 7 días | N/A (manual) | 600s |

### 6.3 Contrato de Atributos Pub/Sub

**outbound-commands:**
```json
Atributos: event_type, vitesse_msg_id, campaign_id, client_id, phone_hash, storage_path, local_ref, event_ts
Body: { "storage_path": "...", "local_ref": "..." }
```

**inbound-events:**
```json
Atributos: event_type=inbound_message, wamid, client_id, campaign_id, vitesse_msg_id, storage_path, event_ts
Body: { "storage_path": "..." }
```

**status-events:**
```json
Atributos: event_type=status_event, gsId, status, client_id, campaign_id, vitesse_msg_id, storage_path, event_ts
Body: { "storage_path": "..." }
```

**projection-updates:**
```json
Atributos: event_type=projection_update, vitesse_msg_id, client_id, campaign_id, storage_path, entity_target=firestore
Body: { "storage_path": "..." }
```

**maintenance-commands:**
```json
Atributos: event_type=maintenance_command, command_type=aggregate|compress|cleanup, target_date
Body: { "customer_id": "...", "job_params": { ... } }
```

**media-commands:**
```json
Atributos: event_type=media_command, media_type, mime_type, vm_conv_id, vm_msg_id, gsId, wamid, client_id, campaign_id, vitesse_msg_id, event_ts
Body: { "source_storage_url": "...", "target_storage_url_prefix": "...", "file_name": "...", "file_hash": "..." }
```

### 6.4 Cloud Scheduler — Jobs de Mantenimiento

| Job | Cron | Topic | command_type |
|-----|------|-------|-------------|
| Aggregator diario | `0 1 * * *` | maintenance-commands | `aggregate` |
| Compressor D-30 | `0 2 * * *` | maintenance-commands | `compress` |
| Cleanup active | `0 * * * *` | maintenance-commands | `cleanup` |
| Purge recent_events | `0 3 * * 0` | maintenance-commands | `purge_recent_events` |

---

## 7. Proyección Viva — Firestore

### 7.1 Modelo de Colecciones

```
Firestore Database: vtss-{env}-{cid}-db
│
├── conversations/
│   └── {vitesse_msg_id}                     TTL: 30 días
│       ├── app, phone, campaign_id, active
│       ├── last_event_ts, last_status, last_preview
│       └── recent_events/
│           └── {doc_aleatorio}              TTL: 30 días + cap 100 docs
│               ├── event_ts, direction
│               ├── gsId, wamid
│               ├── last_status, text_preview
│               └── storage_path
│
├── gsid_map/
│   └── {gsId}                               TTL: 90 días
│       ├── vitesse_msg_id, last_status
│       ├── last_event_ts, delivered_at, read_at
│       └── (proyección consolidada del outbound y sus DLRs)
│
├── wamid_map/
│   └── {wamid}                              TTL: 90 días
│       ├── vitesse_msg_id, direction
│       └── last_event_ts
│
├── active_conv/
│   └── {hash(app+phone)}                    TTL: 72h (configurable por tenant)
│       ├── vitesse_msg_id activo
│       └── updated_at, expires_at
│
├── opt_out_list/
│   └── {hash(app+phone)}                    Sin TTL
│       ├── opted_out=true
│       ├── source: keyword|manual|downstream
│       └── keyword, updated_at
│
├── contacts/
│   └── {contact_id}                         TTL: 365 días
│
├── contacts_lists/
│   └── {list_id}                            TTL: 365 días
│
├── contact_segments/
│   └── {segment_id}                         TTL: 365 días
│
└── broadcast_list/
    └── {campaign_id}                        TTL: 365 días
```

### 7.2 Separación en Dev/Staging (DB compartida)

Las colecciones llevan prefijo `{customer_id}_`:

```
vtss-dev-db/
├── c001_conversations/{vitesse_msg_id}
├── c001_gsid_map/{gsId}
├── c001_active_conv/{hash}
├── c002_conversations/{vitesse_msg_id}
├── c002_gsid_map/{gsId}
└── ...
```

### 7.3 Políticas de IAM sobre Firestore

| Actor | Rol | Alcance |
|-------|-----|---------|
| SA Backend (`-be`) | `roles/datastore.user` | Database del cliente |
| SA Frontend (`-fe`) | `roles/datastore.viewer` | Database del cliente (solo lectura) |
| CRF Processor | `roles/datastore.user` | Todas las databases (env) |
| CRF Projector | `roles/datastore.user` | Todas las databases (env) |

### 7.4 Reglas de Materialización

1. Los DLRs (enqueued/sent/delivered/read) **no crean documentos separados** en `recent_events`. Actualizan `last_status` con merge condicional (no-downgrade: nunca pasar de `delivered` a `sent`).
2. `recent_events` conserva solo los últimos 100 mensajes visibles por conversación (el job Compressor/Purge ejecuta el truncado).
3. `gsid_map/{gsId}` recibe la proyección técnica consolidada del outbound y todos sus DLRs.

---

## 8. Estrategia IAM y Seguridad

### 8.1 Service Accounts por Componente

```
┌─────────────────────────────────────────────────────────────┐
│                CUENTAS DE SERVICIO — WORKLOAD               │
├─────────────────────────────┬───────────────────────────────┤
│  Service Account            │  Roles                        │
├─────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-crf-parser      │  pubsub.publisher             │
│                             │  storage.objectCreator        │
│                             │  datastore.user               │
├─────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-crf-receptor    │  pubsub.publisher             │
│                             │  storage.objectCreator        │
├─────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-crf-sender      │  pubsub.subscriber            │
│                             │  storage.objectAdmin          │
├─────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-crf-processor   │  pubsub.subscriber            │
│                             │  pubsub.publisher             │
│                             │  storage.objectAdmin          │
│                             │  datastore.user               │
├─────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-crf-media       │  pubsub.subscriber            │
│                             │  storage.objectAdmin          │
├─────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-crf-projector   │  pubsub.subscriber            │
│                             │  datastore.user               │
├─────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-scheduler       │  pubsub.publisher             │
│                             │  cloudscheduler.jobRunner     │
└─────────────────────────────┴───────────────────────────────┘
```

### 8.2 Service Accounts por Cliente (Preprod/Prod)

```
┌──────────────────────────────────────────────────────────────┐
│                 CUENTAS DE SERVICIO — POR CLIENTE            │
├──────────────────────────────┬───────────────────────────────┤
│  Service Account             │  Roles (scoped al cliente)    │
├──────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-{cid}-be         │  datastore.user (DB del cid)  │
│  (Backend Admin)             │  storage.objectAdmin (cid)    │
│                              │  pubsub.publisher (cid)       │
│                              │  pubsub.subscriber (cid)      │
├──────────────────────────────┼───────────────────────────────┤
│  vtss-{env}-{cid}-fe         │  datastore.viewer (DB del cid)│
│  (Frontend Read-only)        │  (Solo Firestore, sin Storage)│
└──────────────────────────────┴───────────────────────────────┘
```

---

## 9. Estructura de Módulos Terraform

```
terraform/
│
├── environments/
│   ├── dev/
│   │   ├── main.tf           ← Llama módulos shared
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   ├── staging/              ← Misma estructura que dev
│   ├── preprod/
│   │   ├── main.tf           ← Llama módulos customer con for_each
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   └── prod/                 ← Misma estructura que preprod
│
└── modules/
    ├── gcp_project/          ← Habilita APIs requeridas
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── storage_shared/       ← Buckets compartidos (dev/staging)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── storage_customer/     ← Buckets dedicados por cliente (preprod/prod)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── firestore_shared/     ← DB Firestore compartida (dev/staging)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── firestore_customer/   ← DB Firestore dedicada por cliente (preprod/prod)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── pubsub_shared/        ← Topics compartidos (dev/staging)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── pubsub_customer/      ← Topics dedicados por cliente (preprod/prod)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── iam_customer/         ← SAs y roles por cliente (preprod/prod)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── scheduler/            ← Cloud Scheduler jobs de mantenimiento
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### 9.1 Dependencias entre Módulos

```
gcp_project
    └── storage_shared / storage_customer
    └── firestore_shared / firestore_customer
    └── pubsub_shared / pubsub_customer
            └── iam_customer  (referencia topics y buckets)
                    └── scheduler (referencia topics maintenance)
```

---

## 10. Diagramas de Despliegue

### 10.1 Mapa de Tránsito v11 (El Backbone)

```
Externos                     Productores                   Pub/Sub                    Consumidores
───────────────────────────────────────────────────────────────────────────────────────────────────

Frontend/API                                               outbound-commands
    │                                                      ┌────────────────┐
    ▼                         CRF Parser ─────────────────►│                │─────────► CRF Sender ──► Gupshup/Meta
API Gateway                   Campaign Loader ─────────────►│                │
                                                           └────────────────┘
                                                                 │ DLQ
                                                           deadletter-outbound

Gupshup/Meta Webhooks                                      inbound-events
    │                                                      ┌────────────────┐
    ▼                         CRF Receptor ────────────────►│                │─────────► CRF Processor ──► Firestore
Webhook Endpoint                                           └────────────────┘               │
(por canal)                                                                                 ▼
                                                           projection-updates        Storage /active/
                                                           ┌────────────────┐
                              CRF Processor ───────────────►│                │─────────► CRF Projector ──► Firestore
                                                           └────────────────┘

Gupshup DLR Webhooks                                       status-events
    │                                                      ┌────────────────┐
    ▼                         CRF Receptor DLR ────────────►│                │─────────► CRF Processor DLR
Webhook Endpoint                                           └────────────────┘

Cloud Scheduler                                            maintenance-commands
    │                                                      ┌────────────────┐
    └────────────────────────────────────────────────────►│                │─────────► Aggregator
                                                           │                │─────────► Compressor
                                                           └────────────────┘─────────► Cleanup Worker

Media Inbound                                              media-commands
    │                                                      ┌────────────────┐
    ▼                         CRF Receptor/Processor ──────►│                │─────────► CRF Media Handler ──► Storage /media/
Media Detection                                            └────────────────┘
```

### 10.2 Flujo de Resolución Inbound (Context Funnel)

```
  Inbound Nativo (sin vitesse_msg_id)
           │
           ▼
  ┌─────────────────────────────────┐
  │  ¿Trae context.gsId?            │ → Sí → lookup gsid_map/{gsId} → vitesse_msg_id ✓
  └─────────────────────────────────┘
           │ No
           ▼
  ┌─────────────────────────────────┐
  │  ¿Trae context.id (wamid)?      │ → Sí → lookup wamid_map/{wamid} → vitesse_msg_id ✓
  └─────────────────────────────────┘
           │ No
           ▼
  ┌─────────────────────────────────┐
  │  ¿Existe active_conv[app+phone]?│ → Sí → usar vitesse_msg_id activo ✓
  └─────────────────────────────────┘
           │ No
           ▼
  ┌─────────────────────────────────┐
  │  Crear nuevo vitesse_msg_id     │ → campaign_id = "organic_YYYY_MM"
  │  (transacción sobre active_conv)│
  └─────────────────────────────────┘
```

### 10.3 Estructura de Recursos por Ambiente

```
┌──────────────────────────────────────────────────────────────────┐
│                         PROD / PREPROD                            │
│                                                                  │
│  cliente_A                  cliente_B                  cliente_C │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │vtss-prod-A-msg   │  │vtss-prod-B-msg   │  │vtss-prod-C-msg│ │
│  │vtss-prod-A-mlt   │  │vtss-prod-B-mlt   │  │vtss-prod-C-mlt│ │
│  │vtss-prod-A-db    │  │vtss-prod-B-db    │  │vtss-prod-C-db│  │
│  │Topics: A-*       │  │Topics: B-*       │  │Topics: C-*   │  │
│  │SA: A-be, A-fe    │  │SA: B-be, B-fe    │  │SA: C-be,C-fe │  │
│  └──────────────────┘  └──────────────────┘  └──────────────┘  │
│                                                                  │
│  CRFs compartidos: crf-parser, crf-receptor, crf-sender, ...    │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                          DEV / STAGING                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  vtss-dev-messaging (1 bucket compartido)                  │  │
│  │  vtss-dev-multimedia (1 bucket compartido)                 │  │
│  │  vtss-dev-db         (1 Firestore compartida)              │  │
│  │  Topics compartidos: vtss-dev-outbound-commands, etc.      │  │
│  │                                                            │  │
│  │  Rutas prefijadas por cliente dentro de cada bucket:       │  │
│  │  active/todo/outbound/{customer_id}/...                    │  │
│  │  {customer_id}_conversations/ (Firestore collections)      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 11. Guía de Despliegue

### 11.1 Prerequisitos

```bash
# 1. Instalar Terraform >= 1.5
brew install terraform

# 2. Autenticarse con GCP
gcloud auth application-default login
gcloud auth login

# 3. Crear los proyectos GCP (una vez)
gcloud projects create vtss-dev    --name="Vitesse Dev"
gcloud projects create vtss-stg    --name="Vitesse Staging"
gcloud projects create vtss-preprod --name="Vitesse Preprod"
gcloud projects create vtss-prod   --name="Vitesse Prod"

# 4. Vincular billing accounts
gcloud billing projects link vtss-prod --billing-account=BILLING_ACCOUNT_ID

# 5. Crear el bucket de estado de Terraform por ambiente (bootstrapping)
gsutil mb -p vtss-dev    -l US gs://vtss-dev-tfstate
gsutil mb -p vtss-stg    -l US gs://vtss-stg-tfstate
gsutil mb -p vtss-preprod -l US gs://vtss-preprod-tfstate
gsutil mb -p vtss-prod   -l US gs://vtss-prod-tfstate

# Habilitar versionado en los buckets de estado
gsutil versioning set on gs://vtss-dev-tfstate
gsutil versioning set on gs://vtss-prod-tfstate
```

### 11.2 Despliegue por Ambiente

```bash
# --- DEV ---
cd terraform/environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# --- STAGING ---
cd terraform/environments/staging
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# --- PREPROD (con clientes) ---
cd terraform/environments/preprod
# Editar terraform.tfvars para agregar customer_ids
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# --- PROD ---
cd terraform/environments/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 11.3 Agregar un Nuevo Cliente en Prod

1. Editar `terraform/environments/prod/terraform.tfvars`:
   ```hcl
   customers = ["cliente_001", "cliente_002", "nuevo_cliente"]
   ```

2. Planear y aplicar:
   ```bash
   cd terraform/environments/prod
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

   Terraform creará automáticamente (via `for_each`):
   - 2 buckets de Storage para `nuevo_cliente`
   - 1 database Firestore dedicada
   - 6 topics Pub/Sub + 6 DLQ topics + 12 subscriptions
   - 2 service accounts (backend + frontend)
   - Todos los bindings IAM correspondientes

### 11.4 Orden de Aplicación Recomendado

```
1. gcp_project (APIs)
2. storage_shared / storage_customer
3. firestore_shared / firestore_customer
4. pubsub_shared / pubsub_customer
5. iam_customer
6. scheduler
```

Terraform maneja las dependencias automáticamente vía `depends_on` y referencias entre recursos.

### 11.5 APIs GCP Requeridas

| API | Propósito |
|-----|-----------|
| `storage.googleapis.com` | Cloud Storage |
| `pubsub.googleapis.com` | Cloud Pub/Sub |
| `firestore.googleapis.com` | Firestore |
| `firebase.googleapis.com` | Firebase Auth |
| `run.googleapis.com` | Cloud Run (CRFs) |
| `cloudscheduler.googleapis.com` | Cloud Scheduler |
| `secretmanager.googleapis.com` | Secret Manager |
| `iam.googleapis.com` | IAM |
| `cloudresourcemanager.googleapis.com` | Resource Manager |
| `artifactregistry.googleapis.com` | Container images |
| `cloudbuild.googleapis.com` | CI/CD |
| `monitoring.googleapis.com` | Observabilidad |
| `logging.googleapis.com` | Logging |

---

*Documento generado para Vitesse v11 — Arquitectura Operativa GCP · Mayo 2026*
