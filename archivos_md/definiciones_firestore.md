# POLÍTICAS Y DEFINICIONES DE FIRESTORE (FS_DB)

## POLÍTICA DE INFRAESTRUCTURA

- Se tendrá un despliegue de FS_DB por cada Cliente (`customer_id`) para mantener la segregación virtual de plataformas para los accesos en cuanto a persistencia de datos
- Se tendrá un usuario IAM dedicado con rol por cada Cliente en modo **lectura** para el frontend y otro en modo **escritura** para el backend, esto será en ambiente productivo
- Se usará **Firebase Auth** para la gestión de accesos para los componentes back y front

## POLÍTICA DE SEGURIDAD Y ACCESO

- **Frontend**: solo permiso de lectura, el front no escribirá directamente sobre FS_DB
- **Backend**: SDK de Admin para acceso total sobre la FS_DB

## POLÍTICA DE CONEXIONES

- Se aplicará en frontend el soporte para conexiones "idles", que desactivará los _listeners_ cuando el usuario no tenga la aplicación en el primer plano
- Se aplicará en frontend el requisito de realizar todas las peticiones paginadas para los resultados, con un límite configurable. Ej: 20

## POLÍTICA DE RETENCIÓN DE DOCUMENTOS

- Se usará el feature de **TTL** de Firebase para manejar la expiración de los documentos en FS, con una ventana de tiempo configurable por tipo de documento. Ej: 30 días para conversaciones, 70 días para Resumen de envío Broadcast, 120 días para historial de gestión, etc. Usando un campo en el documento que le indicará al colector de FS en qué momento retirarlo de la FS_DB.
- No se limitará la cantidad de documentos en esta etapa.
- Se tendrá un límite máximo de tamaño de **1MB por documento**, lo que se considera suficiente ya que no se manejarán multimedias. Si los mensajes tienen un límite de 1024 caracteres heredado del proveedor Meta, 1MB es suficiente para almacenarlos incluyendo la potencial metadata de los payloads y demás componentes de la proyección individual.

## NOMENCALTURA DE COLECCIONES Y DOCUMENTOS

- Se tendrán las siguientes colecciones/documentos, van orientadas a almacenar la información lo más cercana a su lectura por parte del front:
	- conversations: cada documento representa una conversación con el contenido para mostrar en el panel 1 de la aplicación. Incluye embebido los datos de la sesión, el contacto y sus tags, el canal por el cual se realiza, datos del cliente dueño del canal, del agente asignado, las notas de la conversación. TTL: 30 días
	- messages_conversations: cada documento contiene el arreglo de los mensajes de cada conversación para mostrar en el panel 2 de la aplicación web; el listado de los mensajes (todo su payload y apuntadores al archivo de media en caso que tenga). TTL: 60 días
	- conversations_audit_history: cada documento representa el listado de las trazas de modificaciones sobre las conversaciones, uno por cada conversación, que puede ser consultado de forma paginada y/o filtrada por fechas. TTL: 120 días
	- contacts: cada documento representa un contacto con sus atributos, incluyendo pertenencia a listas, tipo y canal, tags. TTL: 365 días
	- contacts_lists: cada documento representa una lista de contactos con sus atributos y los id's de contactos que pertenecen a esta. TTL: 365 días
	- contact_segments: cada documento representa una consulta específica en un momento determinado sobre la tabla de contactos con sus atributos y los id's de contactos que coinciden con esta consulta en un tiempo determinado. TTL: 365 días
	- broadcast_list: cada documento representa una campaña con sus atributos y estadísticas, y el detalle de cada tarea de envío a realiza por contacto, así como el mensaje relacionado que contiene su estado actual. TTL 365
	


