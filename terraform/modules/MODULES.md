# Terraform Modules — Vitesse v11

```
terraform/modules/
├── gcp_project/        ← APIs + workload service accounts (todos los ambientes)
├── storage_shared/     ← 2 buckets compartidos (dev / stg)
├── storage_customer/   ← 2 buckets dedicados por cliente (preprod / prod)
├── firestore_shared/   ← 1 base de datos Firestore compartida (dev / stg)
├── firestore_customer/ ← 1 base de datos Firestore por cliente (preprod / prod)
├── pubsub_shared/      ← 12 topics + 12 subscriptions compartidos (dev / stg)
├── pubsub_customer/    ← 12 topics + 12 subscriptions por cliente (preprod / prod)
├── iam_customer/       ← 2 service accounts + IAM bindings por cliente (preprod / prod)
└── scheduler/          ← 4 Cloud Scheduler jobs de mantenimiento
```

---

## gcp_project

Habilita las APIs del proyecto y crea los service accounts de workload compartidos por todos los clientes dentro del ambiente.

### Variables

| Variable | Tipo | Requerida | Descripcion |
|:---------|:----:|:---------:|:------------|
| `project_id` | string | si | GCP project ID |
| `env` | string | si | `dev` \| `stg` \| `preprod` \| `prod` |
| `region` | string | no | Default `us-central1` |

### Recursos creados

**APIs habilitadas** via `google_project_service` (`disable_on_destroy = false`):

| API | Servicio |
|:----|:---------|
| `storage.googleapis.com` | Cloud Storage |
| `pubsub.googleapis.com` | Cloud Pub/Sub |
| `firestore.googleapis.com` | Firestore |
| `firebase.googleapis.com` | Firebase |
| `run.googleapis.com` | Cloud Run |
| `cloudscheduler.googleapis.com` | Cloud Scheduler |
| `secretmanager.googleapis.com` | Secret Manager |
| `iam.googleapis.com` | IAM |
| `cloudresourcemanager.googleapis.com` | Resource Manager |
| `artifactregistry.googleapis.com` | Artifact Registry |
| `cloudbuild.googleapis.com` | Cloud Build |
| `monitoring.googleapis.com` | Cloud Monitoring |
| `logging.googleapis.com` | Cloud Logging |
| `cloudtrace.googleapis.com` | Cloud Trace |

**Service accounts workload** via `google_service_account`:

| Recurso | `account_id` | Roles IAM asignados |
|:--------|:-------------|:--------------------|
| `crf_parser` | `vtss-{env}-crf-parser` | `pubsub.publisher`, `storage.objectCreator`, `datastore.user` |
| `crf_receptor` | `vtss-{env}-crf-receptor` | `pubsub.publisher`, `storage.objectCreator` |
| `crf_sender` | `vtss-{env}-crf-sender` | `pubsub.subscriber`, `storage.objectAdmin` |
| `crf_processor` | `vtss-{env}-crf-processor` | `pubsub.subscriber`, `pubsub.publisher`, `storage.objectAdmin`, `datastore.user` |
| `crf_media` | `vtss-{env}-crf-media` | `pubsub.subscriber`, `storage.objectAdmin` |
| `crf_projector` | `vtss-{env}-crf-projector` | `pubsub.subscriber`, `datastore.user` |
| `scheduler` | `vtss-{env}-scheduler` | `pubsub.publisher` |

Los roles se asignan a nivel de proyecto via `google_project_iam_member`.

### Outputs

| Output | Valor |
|:-------|:------|
| `workload_sa_emails` | `map(string)` con los emails de los 7 SAs |

---

## storage_shared

Usado en **dev** y **stg**. Crea 2 buckets compartidos entre todos los clientes del ambiente. El aislamiento por cliente se logra via prefijo de objeto (`{customer_id}/...`).

### Variables

| Variable | Tipo | Default | Descripcion |
|:---------|:----:|:-------:|:------------|
| `project_id` | string | — | GCP project ID |
| `env` | string | — | Ambiente |
| `region` | string | `US` | Ubicacion del bucket |
| `bucket_prefix` | string | `vtss` | Prefijo del nombre |
| `labels` | map(string) | `{}` | Labels comunes |

### Recursos creados

#### `google_storage_bucket.messaging` — `vtss-{env}-messaging`

| Configuracion | Valor |
|:--------------|:------|
| `uniform_bucket_level_access` | `true` |
| `public_access_prevention` | `enforced` |
| `versioning` | deshabilitado |

Lifecycle rules:

| Prefijo | Condicion | Accion |
|:--------|:---------:|:-------|
| `active/done/` | age > 45 dias | Delete |
| `active/in_process/` | age > 7 dias | Delete |
| `active/error/` | age > 90 dias | Delete |
| `archived/` | age > 30 dias | SetStorageClass → NEARLINE |
| `archived/` | age > 365 dias | SetStorageClass → COLDLINE |
| `data/` | age > 30 dias | SetStorageClass → NEARLINE |
| `data/` | age > 730 dias | Delete |

#### `google_storage_bucket.multimedia` — `vtss-{env}-multimedia`

| Configuracion | Valor |
|:--------------|:------|
| `uniform_bucket_level_access` | `true` |
| `public_access_prevention` | `enforced` |
| `versioning` | habilitado |
| CORS `origin` | `["*"]` |
| CORS `method` | `GET`, `HEAD` |
| CORS `max_age_seconds` | `3600` |

Lifecycle rules:

| Prefijo | Condicion | Accion |
|:--------|:---------:|:-------|
| `conversational_files/`, `catalog_files/` | age > 90 dias | SetStorageClass → NEARLINE |
| — | `num_newer_versions` > 3 | Delete |

### Outputs

| Output | Valor |
|:-------|:------|
| `messaging_bucket_name` | Nombre del bucket de mensajeria |
| `multimedia_bucket_name` | Nombre del bucket multimedia |

---

## storage_customer

Usado en **preprod** y **prod**. Instanciado via `for_each = toset(var.customers)`. Cada cliente recibe sus propios 2 buckets completamente aislados.

### Variables

| Variable | Tipo | Default | Descripcion |
|:---------|:----:|:-------:|:------------|
| `project_id` | string | — | GCP project ID |
| `env` | string | — | Ambiente |
| `customer_id` | string | — | ID del cliente (regex `^[a-z0-9_-]+$`) |
| `region` | string | `US` | Ubicacion del bucket |
| `bucket_prefix` | string | `vtss` | Prefijo del nombre |
| `labels` | map(string) | `{}` | Labels comunes |

### Recursos creados

#### `google_storage_bucket.messaging` — `vtss-{env}-{customer_id}-msg`

Mismas lifecycle rules que `storage_shared.messaging`. Labels adicionales: `isolation = "dedicated"`, `customer_id = {customer_id}`.

#### `google_storage_bucket.multimedia` — `vtss-{env}-{customer_id}-mlt`

Mismas lifecycle rules y configuracion CORS que `storage_shared.multimedia`. Labels adicionales: `isolation = "dedicated"`, `customer_id = {customer_id}`.

### Outputs

| Output | Valor |
|:-------|:------|
| `messaging_bucket_name` | `vtss-{env}-{customer_id}-msg` |
| `multimedia_bucket_name` | `vtss-{env}-{customer_id}-mlt` |

---

## firestore_shared

Usado en **dev** y **stg**. Crea una unica base de datos Firestore compartida. Las colecciones llevan el prefijo `{customer_id}_` para separacion logica (ej. `acme_conversations`).

### Variables

| Variable | Tipo | Descripcion |
|:---------|:----:|:------------|
| `project_id` | string | GCP project ID |
| `env` | string | Ambiente |
| `location_id` | string | Region de Firestore (ej. `nam5`) |

### Recursos creados

#### `google_firestore_database.shared` — `vtss-{env}-db`

| Configuracion | Valor |
|:--------------|:------|
| `type` | `FIRESTORE_NATIVE` |
| `concurrency_mode` | `OPTIMISTIC` |
| `app_engine_integration_mode` | `DISABLED` |
| `delete_protection_state` | `ENABLED` si prod/preprod, `DISABLED` si dev/stg |

#### `google_firestore_field` — TTL por coleccion

Las colecciones usan el prefijo `(default)_` para el shared DB:

| Coleccion | Campo TTL |
|:----------|:----------|
| `(default)_conversations` | `ttl_timestamp` |
| `(default)_recent_events` | `ttl_timestamp` |
| `(default)_gsid_map` | `ttl_timestamp` |
| `(default)_wamid_map` | `ttl_timestamp` |
| `(default)_active_conv` | `ttl_timestamp` |
| `(default)_contacts` | `ttl_timestamp` |
| `(default)_broadcast_list` | `ttl_timestamp` |

### Outputs

| Output | Valor |
|:-------|:------|
| `database_id` | Nombre de la base de datos |

---

## firestore_customer

Usado en **preprod** y **prod**. Instanciado via `for_each`. Cada cliente recibe su propia base de datos Firestore con delete protection siempre habilitada.

### Variables

| Variable | Tipo | Descripcion |
|:---------|:----:|:------------|
| `project_id` | string | GCP project ID |
| `env` | string | Ambiente |
| `customer_id` | string | ID del cliente |
| `location_id` | string | Region de Firestore |

### Recursos creados

#### `google_firestore_database.customer` — `vtss-{env}-{customer_id}-db`

| Configuracion | Valor |
|:--------------|:------|
| `type` | `FIRESTORE_NATIVE` |
| `concurrency_mode` | `OPTIMISTIC` |
| `app_engine_integration_mode` | `DISABLED` |
| `delete_protection_state` | `DELETE_PROTECTION_ENABLED` (siempre) |

#### `google_firestore_field` — TTL por coleccion

11 configuraciones TTL, todas sobre el campo `ttl_timestamp`:

| Coleccion | TTL referencia |
|:----------|:--------------|
| `conversations` | 30 dias |
| `recent_events` | 30 dias + cap 100 eventos (enforced por Compressor job) |
| `gsid_map` | 90 dias |
| `wamid_map` | 90 dias |
| `active_conv` | 72 h (configurable por tenant via aplicacion) |
| `contacts` | 365 dias |
| `contacts_lists` | 365 dias |
| `contact_segments` | 365 dias |
| `broadcast_list` | 365 dias |
| `messages_conversations` | 60 dias |
| `conversations_audit_history` | 120 dias |

> El TTL lo escribe la aplicacion al crear el documento. Terraform solo registra el campo como indice TTL via `ttl_config {}`.

### Outputs

| Output | Valor |
|:-------|:------|
| `database_id` | `vtss-{env}-{customer_id}-db` |

---

## pubsub_shared

Usado en **dev** y **stg**. Crea los 12 topics (6 operacionales + 6 DLQ) y las 6 subscriptions compartidas.

### Variables

| Variable | Tipo | Default | Descripcion |
|:---------|:----:|:-------:|:------------|
| `project_id` | string | — | GCP project ID |
| `env` | string | — | Ambiente |
| `project_number` | string | — | Numero de proyecto (para SA de Pub/Sub) |
| `message_retention_duration` | string | `604800s` | Retencion por defecto (7 dias) |
| `ack_deadline_outbound` | number | `60` | Deadline en segundos para outbound |
| `ack_deadline_inbound` | number | `30` | Deadline en segundos para inbound/status |
| `ack_deadline_media` | number | `120` | Deadline en segundos para media |
| `ack_deadline_maintenance` | number | `120` | Deadline en segundos para mantenimiento |
| `max_delivery_attempts` | number | `5` | Intentos antes de enviar a DLQ |
| `labels` | map(string) | `{}` | Labels comunes |

### Recursos creados

#### Topics operacionales — `google_pubsub_topic.main`

Prefijo de nombre: `vtss-{env}`

| Clave | Nombre del topic | Retencion |
|:------|:-----------------|:---------:|
| `outbound_commands` | `vtss-{env}-outbound-commands` | 7 dias |
| `inbound_events` | `vtss-{env}-inbound-events` | 7 dias |
| `status_events` | `vtss-{env}-status-events` | 7 dias |
| `projection_updates` | `vtss-{env}-projection-updates` | 3 dias |
| `maintenance_commands` | `vtss-{env}-maintenance-commands` | 1 dia |
| `media_commands` | `vtss-{env}-media-commands` | 3 dias |

#### Topics DLQ — `google_pubsub_topic.dlq`

| Clave | Nombre del topic DLQ |
|:------|:---------------------|
| `outbound_commands` | `vtss-{env}-dlq-outbound` |
| `inbound_events` | `vtss-{env}-dlq-inbound` |
| `status_events` | `vtss-{env}-dlq-status` |
| `projection_updates` | `vtss-{env}-dlq-projection` |
| `maintenance_commands` | `vtss-{env}-dlq-maintenance` |
| `media_commands` | `vtss-{env}-dlq-media` |

Cada DLQ topic tiene su propia subscription (`{dlq-name}-sub`) con `retain_acked_messages = true` y `expiration_policy.ttl = ""` (nunca expira).

El SA `service-{project_number}@gcp-sa-pubsub.iam.gserviceaccount.com` recibe `roles/pubsub.publisher` en todos los DLQ topics via `google_pubsub_topic_iam_member.dlq_publisher`.

#### Subscriptions operacionales — `google_pubsub_subscription`

| Nombre | Topic fuente | Ack deadline | DLQ | Backoff |
|:-------|:-------------|:------------:|:---:|:-------:|
| `vtss-{env}-sub-crf-sender` | `outbound-commands` | 60 s | `dlq-outbound` | 10 s – 300 s |
| `vtss-{env}-sub-crf-processor-inbound` | `inbound-events` | 30 s | `dlq-inbound` | 5 s – 120 s |
| `vtss-{env}-sub-crf-processor-status` | `status-events` | 30 s | `dlq-status` | 5 s – 120 s |
| `vtss-{env}-sub-crf-projector` | `projection-updates` | 30 s | `dlq-projection` | 5 s – 60 s |
| `vtss-{env}-sub-maintenance-workers` | `maintenance-commands` | 120 s | `dlq-maintenance` | 30 s – 600 s |
| `vtss-{env}-sub-crf-media-handler` | `media-commands` | 120 s | `dlq-media` | 10 s – 300 s |

Cada subscription otorga `roles/pubsub.subscriber` al SA de Pub/Sub via `google_pubsub_subscription_iam_member` (requerido para que la `dead_letter_policy` funcione).

### Outputs

| Output | Contenido |
|:-------|:----------|
| `topic_ids` | `map(string)` — IDs completos de los 6 topics operacionales |
| `topic_names` | `map(string)` — Nombres cortos |
| `dlq_topic_ids` | `map(string)` — IDs completos de los 6 DLQ topics |
| `subscription_ids` | `map(string)` — IDs completos de las 6 subscriptions |
| `maintenance_topic_id` | ID del topic `maintenance-commands` |

---

## pubsub_customer

Identico en estructura a `pubsub_shared` pero instanciado via `for_each` por cliente. El prefijo de todos los recursos es `vtss-{env}-{customer_id}`.

### Variables

Mismas que `pubsub_shared` mas:

| Variable adicional | Tipo | Descripcion |
|:-------------------|:----:|:------------|
| `customer_id` | string | ID del cliente |

### Recursos creados

Misma estructura que `pubsub_shared`. Los nombres de topics y subscriptions incluyen `{customer_id}`:

- Topics: `vtss-{env}-{cid}-outbound-commands`, `vtss-{env}-{cid}-inbound-events`, etc.
- DLQs: `vtss-{env}-{cid}-dlq-outbound`, etc.
- Subscriptions: `vtss-{env}-{cid}-sub-crf-sender`, etc.

Los labels incluyen `customer_id = {customer_id}`.

### Outputs

| Output | Contenido |
|:-------|:----------|
| `topic_ids` | `map(string)` — IDs de los 6 topics operacionales del cliente |
| `topic_names` | `map(string)` — Nombres cortos |
| `dlq_topic_ids` | `map(string)` — IDs de los 6 DLQ topics |
| `subscription_ids` | `map(string)` — IDs de las 6 subscriptions |
| `maintenance_topic_id` | ID del topic `maintenance-commands` del cliente |

---

## iam_customer

Usado en **preprod** y **prod**. Instanciado via `for_each`. Crea 2 service accounts por cliente y otorga permisos sobre los recursos del mismo cliente y acceso de los workload SAs a dichos recursos.

### Variables

| Variable | Tipo | Descripcion |
|:---------|:----:|:------------|
| `project_id` | string | GCP project ID |
| `env` | string | Ambiente |
| `customer_id` | string | ID del cliente |
| `messaging_bucket_name` | string | Nombre del bucket de mensajeria del cliente |
| `multimedia_bucket_name` | string | Nombre del bucket multimedia del cliente |
| `firestore_database_id` | string | ID de la base de datos Firestore del cliente |
| `pubsub_topic_ids` | map(string) | IDs de los topics del cliente |
| `pubsub_subscription_ids` | map(string) | IDs de las subscriptions del cliente |
| `workload_sa_emails` | map(string) | Emails de los 7 workload SAs (output de `gcp_project`) |

### Recursos creados

#### Service accounts — `google_service_account`

| Recurso | `account_id` | Uso |
|:--------|:-------------|:----|
| `backend` | `vtss-{env}-{cid}-be` | Acceso admin al stack del cliente |
| `frontend` | `vtss-{env}-{cid}-fe` | Acceso read-only a Firestore |

#### IAM bindings — Backend SA

| Recurso destino | Role |
|:----------------|:-----|
| `messaging_bucket_name` | `roles/storage.objectAdmin` |
| `multimedia_bucket_name` | `roles/storage.objectAdmin` |
| Proyecto (Firestore) | `roles/datastore.user` |
| Todos los topics del cliente | `roles/pubsub.publisher` |
| Todas las subscriptions del cliente | `roles/pubsub.subscriber` |

#### IAM bindings — Frontend SA

| Recurso destino | Role |
|:----------------|:-----|
| Proyecto (Firestore) | `roles/datastore.viewer` |

#### IAM bindings — Workload SAs

Todos los workload SAs del ambiente reciben acceso `roles/storage.objectAdmin` sobre los 2 buckets del cliente via `google_storage_bucket_iam_member` (iterado con `for_each = var.workload_sa_emails`).

El SA `crf_processor` recibe adicionalmente `roles/pubsub.publisher` sobre todos los topics del cliente.

### Outputs

| Output | Valor |
|:-------|:------|
| `backend_sa_email` | Email del SA backend del cliente |
| `frontend_sa_email` | Email del SA frontend del cliente |
| `backend_sa_name` | Resource name completo del SA backend |
| `frontend_sa_name` | Resource name completo del SA frontend |

---

## scheduler

Crea los 4 jobs de mantenimiento de Cloud Scheduler. Usado en todos los ambientes. En prod se instancia una vez por cliente (`for_each`), apuntando al topic `maintenance-commands` de ese cliente.

### Variables

| Variable | Tipo | Default | Descripcion |
|:---------|:----:|:-------:|:------------|
| `project_id` | string | — | GCP project ID |
| `env` | string | — | Ambiente |
| `region` | string | `us-central1` | Region del job |
| `scheduler_sa_email` | string | — | Email del SA `vtss-{env}-scheduler` |
| `maintenance_topic_id` | string | — | ID completo del topic `maintenance-commands` |
| `customer_ids` | list(string) | `[]` | IDs de clientes para jobs con scope `customer` |
| `time_zone` | string | `America/Bogota` | Zona horaria del cron |

### Recursos creados

#### `google_cloud_scheduler_job` — 4 jobs

Todos los jobs publican a `maintenance_topic_id` via `pubsub_target`. El payload es JSON codificado en base64.

| Recurso | Nombre | Schedule | Payload `command_type` |
|:--------|:-------|:--------:|:----------------------|
| `daily_aggregator` | `vtss-{env}-job-daily-aggregator` | `0 1 * * *` | `aggregate` |
| `daily_compressor` | `vtss-{env}-job-daily-compressor` | `0 2 * * *` | `compress` |
| `hourly_cleanup` | `vtss-{env}-job-hourly-cleanup` | `0 * * * *` | `cleanup` |
| `weekly_purge_recent_events` | `vtss-{env}-job-weekly-purge-recent-events` | `0 3 * * 0` | `purge_recent_events` |

Detalle de payloads:

**daily_aggregator** — Lee `/active/done` + `/active/error` y produce resumenes por campana/app.
```json
{ "command_type": "aggregate", "target_date": "YESTERDAY", "scope": "customer|all", "customer_ids": [...] }
```

**daily_compressor** — Mueve objetos `/active/done/{D-30}` a `/archived/` como `jsonl.gz`.
```json
{ "command_type": "compress", "target_date": "D-30", "scope": "customer|all", "customer_ids": [...] }
```

**hourly_cleanup** — Elimina objetos huerfanos en `in_process` y verifica salud de la queue activa.
```json
{ "command_type": "cleanup", "scope": "customer|all", "customer_ids": [...] }
```

**weekly_purge_recent_events** — Trunca `recent_events` en Firestore: cap de 100 eventos o 30 dias.
```json
{ "command_type": "purge_recent_events", "max_events": 100, "max_days": 30, "scope": "customer|all", "customer_ids": [...] }
```

`scope` es `"customer"` cuando `length(var.customer_ids) > 0`, de lo contrario `"all"`.

Adicionalmente se crea `google_project_iam_member.scheduler_invoker` con `roles/cloudscheduler.jobRunner` para el SA scheduler.

### Outputs

| Output | Contenido |
|:-------|:----------|
| `job_names` | `map(string)` con los 4 nombres de jobs |
