# `contrato_identificadores.md`

# Contrato de Identificadores

Definición y cierre del contrato de identificadores para conversaciones, mensajes y referencias locales.

Incluye:

* `vm_conv_id`
* `vm_msg_id`
* `local_ref`
* `gsId`
* `wamid`
* regla de nacimiento de archivos y eventos

---

# Estructura General Propuesta para Almacenamiento de Archivos

Basada en `Conversation ID`.

```txt
{channel_provider}/{channel_identifier}/{contact_identifier}/YYYYMM/{timestamp}-{uuid[:6]}.json
```

---

# 1. Vitesse Conversation ID

Identificador único de conversación.

Será la raíz principal del almacenamiento de eventos `inbound` y `outbound`.

---

## `vm_conv_id`

### channel_provider

| Canal     | Valor                       |
| --------- | --------------------------- |
| WhatsApp  | `whatsapp_business_account` |
| Instagram | `instagram`                 |
| Messenger | `page`                      |

---

### channel_identifier

Identificador de canal por el cual se comunican.

| Canal     | Valor                         |
| --------- | ----------------------------- |
| WhatsApp  | `phone_number_id`             |
| Instagram | `entry[].id` o `recipient.id` |
| Messenger | `entry[].id` o `recipient.id` |

---

### contact_identifier

Identificador del contacto que envía el mensaje.

| Canal     | Valor                                                                    |
| --------- | ------------------------------------------------------------------------ |
| WhatsApp  | `user_id` *(tener en cuenta migración desde `phone_number` a `user_id`)* |
| Instagram | `entry[].messaging.sender.id`                                            |
| Messenger | `entry[].messaging.sender.id`                                            |

---

## Estructura

```txt
{channel_provider}/{channel_identifier}/{contact_identifier}
```

> Hasta acá corresponde el `vm_conv_id`.

---

# 2. Vitesse Message ID

Identificador único de mensaje dentro de una conversación.

---

## `vm_msg_id`

### Componentes

| Campo       | Descripción                               |
| ----------- | ----------------------------------------- |
| `YYYYMMDD`  | Año, mes y día del evento en UTC-0        |
| `timestamp` | Timestamp del evento                      |
| `uuid[:6]`  | Últimos 6 caracteres de un UUID aleatorio |

---

### Reglas

* Para mensajes `outbound`, inicialmente el `timestamp` corresponderá al `local_ref`.
* El `local_ref` llegará desde el cliente consumidor.
* Formato timestamp ISO:

```txt
YYYY-MM-DDTHH:mm:ss.sssZ
```

---

## Estructura

```txt
YYYYMMDD/{timestamp}-{uuid[:6]}.json
```

---

# 3. Referencia Local

Identificador temporal del mensaje mientras se recibe el ID del proveedor.

---

## `local_ref`

### Componentes

| Campo       | Descripción                            |
| ----------- | -------------------------------------- |
| `timestamp` | Timestamp ISO del evento               |
| `uuid[:6]`  | Últimos 6 caracteres de UUID aleatorio |

---

### Formato timestamp

```txt
YYYY-MM-DDTHH:mm:ss.sssZ
```

---

## Estructura

```txt
{timestamp}-{uuid[:6]}.json
```

---

# 4. Gupshup ID

Identificador único generado por Gupshup.

Aplica únicamente para proveedor WhatsApp Meta Business.

---

## `gsId`

Identificador asignado por Gupshup.

---

## Outbound

Se genera síncronamente durante el envío del mensaje.

### Fuente

```txt
messages[].id
```

---

## Inbound

### Mensajes

```txt
entry[].changes[].value.messages[].context.gs_id
```

### Eventos

```txt
changes[].values.statuses[].gs_id
```

---

## Estructura

```txt
<provider_defined_value>
```

---

# 5. Meta Message ID

Identificador único del mensaje en la plataforma Meta.

---

## `wamid`

Identificador asignado por Meta.

---

## Outbound

### WhatsApp vía Gupshup

Se recibe desde el primer evento de estado del mensaje.

El mapeo se realiza utilizando el `gsId`.

### Instagram y Messenger

Se recibe en la respuesta síncrona al envío.

### Fuente

```txt
message.message_id
```

---

## Inbound

### Mensajes WhatsApp

```txt
entry[].changes[].value.messages[].context.meta_msg_id
```

### Eventos WhatsApp

```txt
changes[].values.statuses[].meta_msg_id
```

### Instagram y Messenger

```txt
entry[].messaging[].message.mid
```

---

# 6. ID Campaña

Identificador de mensajes asociados a campañas (`broadcast`).

---

## Reglas Generales

* Siempre nace desde un `outbound`.
* Un `outbound` puede o no pertenecer a campaña.
* Un `inbound` nunca crea un `campaign_id`.
* No hace parte de la estructura principal.
* Se utilizará como estructura secundaria de apuntadores.
* Permitirá agregaciones rápidas de resultados y evolución.

---

## Campos

### channel_provider

| Canal     | Valor                       |
| --------- | --------------------------- |
| WhatsApp  | `whatsapp_business_account` |
| Instagram | `instagram`                 |
| Messenger | `page`                      |

---

### channel_identifier

| Canal    | Valor             |
| -------- | ----------------- |
| WhatsApp | `phone_number_id` |

---

### id_campana

Consecutivo generado durante la configuración de campaña en la aplicación.

---

## Estructura

```txt
{channel_provider}-{channel_identifier}-{id_campana}/
```

---

# Regla de Nacimiento

Todas las cargas útiles y archivos reales deberán finalizar en la estructura definida por `vm_conv_id`.

---

## Outbound

### Flujo

1. Con información del evento, generar archivo:

```txt
/active/todo/outbound/{vm_conv_id}/{vm_msg_id}
```

2. Si el evento contiene `campaign_id`:

* Generar estructura apuntadora de campaña.
* Crear archivos `symlink` hacia la estructura principal.

---

## Inbound

### Si `message_type`

Generar mapeo directo usando `vm_conv_id`.

> Todos los mensajes inbound traen la información necesaria para construirlo.

---

### Si `event_type`

Intentar resolución en el siguiente orden:

1. Mapeo por `wamid`
2. Mapeo por `gsId`

---

### Si no es posible mapear

Enviar el evento a:

```txt
DQL
```
