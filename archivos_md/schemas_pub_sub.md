# `outbound-cmd.schema.json`

## Event

La tarea debe llevar los siguientes campos para un almacenamiento rápido en el directorio `todo`:

| Campo                     | Tipo       | Descripción                                                                                   |
| ------------------------- | ---------- | --------------------------------------------------------------------------------------------- |
| `request_timestamp`       | `datetime` | Fecha y hora de creación del request                                                          |
| `request_client_uuid[:6]` | `string`   | Prefijo de 6 caracteres del UUID del cliente                                                  |
| `channel_provider`        | `string`   | Proveedor del canal                                                                           |
| `channel_identifier`      | `string`   | Identificador del canal                                                                       |
| `contact_identifier`      | `string`   | Identificador del contacto                                                                    |
| `message_type`            | `enum`     | `text \| image \| audio \| video \| interactive \| template \| sticker \| button \| document` |

---

## Payload

La carga útil tendrá el `id_campana` en caso de pertenecer a una campaña (*Broadcast*).

```json
{
  "id_campana": "string (optional)",
  "message": {
    "...": "dict provider required payload"
  }
}
```

---

# `inbound-evt.schema.json`

Para otorgar rapidez, se configurará un webhook diferente por cada canal, de forma que desde la URI en la que se reciba el request se puedan obtener los datos de proveedor e identificador del canal.

## Event

| Campo                | Tipo       | Descripción                           |
| -------------------- | ---------- | ------------------------------------- |
| `request_timestamp`  | `datetime` | Fecha y hora de recepción del request |
| `channel_provider`   | `string`   | Proveedor del canal                   |
| `channel_identifier` | `string`   | Identificador del canal               |
| `event_type`         | `enum`     | `message \| event`                    |

---

## Payload

La carga útil recibida por cada tipo de provider.

```json
{
  "...": "dict provider required payload"
}
```

---

# `status-evt.schema.json`

## Event

| Campo                | Tipo       | Descripción             |
| -------------------- | ---------- | ----------------------- |
| `request_timestamp`  | `datetime` | Fecha y hora del evento |
| `channel_provider`   | `string`   | Proveedor del canal     |
| `channel_identifier` | `string`   | Identificador del canal |
| `event_type`         | `enum`     | `event`                 |

---

## Payload

La carga útil recibida por cada tipo de provider.

```json
{
  "...": "dict provider required payload"
}
```

---

# `projection-upd.schema.json`

## Event

| Campo                     | Tipo       | Descripción                                                                                                  |
| ------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------ |
| `request_timestamp`       | `datetime` | Fecha y hora del request                                                                                     |
| `request_client_uuid[:6]` | `string`   | Prefijo de 6 caracteres del UUID del cliente                                                                 |
| `vm_conv_id`              | `string`   | ID de la conversación                                                                                        |
| `event_type`              | `enum`     | `message \| event`                                                                                           |
| `message_type`            | `enum`     | Si es mensaje: `text \| image \| audio \| video \| interactive \| template \| sticker \| button \| document` |

---

## Payload

```json
{
  "...": "dict provider required payload"
}
```

---

# `maintenance-cmd.schema.json`

## Event

| Campo          | Tipo       | Descripción                                |
| -------------- | ---------- | ------------------------------------------ |
| `command_type` | `enum`     | `aggregate \| compress \| cleanup \| sync` |
| `target_task`  | `string`   | Nombre de la tarea a ejecutarse            |
| `target_date`  | `datetime` | Fecha y hora de ejecución                  |

---

## Payload

```json
{
  "customer_id": "string",
  "job_params": {
    "...": "varía de acuerdo a la tarea definida"
  }
}
```

---

# `media-cmd.schema.json`

## Event

| Campo                 | Tipo     | Descripción                       |
| --------------------- | -------- | --------------------------------- |
| `vm_conv_id`          | `string` | ID de la conversación relacionada |
| `vm_msg_id`           | `string` | ID del mensaje relacionado        |
| `gsId`                | `string` | Si existe, se relaciona           |
| `wamid`               | `string` | Si existe, se relaciona           |
| `message_direction`   | `enum`   | `inbound \| outbound`             |
| `media_type`          | `string` | Tipo de media                     |
| `mime_type`           | `string` | MIME type del archivo             |
| `process_type`        | `enum`   | `save \| download \| delete`      |
| `source_storage_type` | `enum`   | `Meta \| Gupshup \| OwnedBucket`  |
| `target_storage_type` | `enum`   | `Meta \| Gupshup \| OwnedBucket`  |

> Dependiendo de la dirección y de dónde se encuentre el asset, se deben realizar acciones diferentes.

---

## Payload

```json
{
  "source_storage_url": "string",
  "target_storage_url_prefix": "string",
  "file_name": "string",
  "file_extension": "string",
  "file_metadata": {},
  "file_hash": "string"
}
```
