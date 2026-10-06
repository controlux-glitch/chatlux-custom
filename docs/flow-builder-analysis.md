# Flow Builder — Análisis de la arquitectura actual (Fase 1)

> Estado: **solo investigación**. Ningún código de producto se ha modificado todavía.
> Objetivo: entender qué existe hoy en Chatwoot antes de diseñar el motor de automatización visual ("Flow Builder"), para maximizar reutilización y minimizar duplicación.

## 1. Resumen ejecutivo

Chatwoot ya tiene casi todos los "huesos" necesarios para un motor de flujos:

| Necesidad del Flow Builder | Ya existe en Chatwoot como... |
|---|---|
| Definición de reglas como datos (no código) | `AutomationRule#conditions` / `#actions` (jsonb) |
| Bus de eventos para disparar lógica al crear/actualizar conversaciones/mensajes | `Dispatcher` (patrón Wisper) + `Events::Types` + listeners síncronos/asíncronos |
| Motor de acciones desacoplado | `ActionService` / `AutomationRules::ActionService` |
| Envío de mensajes agnóstico de canal | `SendReplyJob` + `Base::SendOnChannelService` + `CHANNEL_SERVICES` |
| Recepción de mensajes de WhatsApp Cloud API | `Webhooks::WhatsappController` → `Webhooks::WhatsappEventsJob` → `Whatsapp::IncomingMessage(WhatsappCloud)Service` |
| Botones/listas interactivas de WhatsApp (envío) | `content_type: 'input_select'` + `Whatsapp::Providers::BaseService#create_payload_based_on_items` |
| Plantillas de WhatsApp | `Channel::Whatsapp#message_templates` + `Whatsapp::TemplateProcessorService` |
| Interpolación de variables `{{contact.name}}` | Liquid (`Liquidable` concern + Drops) |
| Bloqueo/idempotencia ante mensajes concurrentes | `Redis::Alfred` + patrón token+compare-and-delete (`AutoAssignment::AssignmentJob`) |
| Autorización multi-tenant | Pundit (`ApplicationPolicy`) + `Current.account.<asociación>` |
| Handoff bot → humano | `Conversation#assignee_agent_bot_id` vs `#assignee_id`, `bot_handoff!` |
| Extensión Enterprise sin fork | `include_mod_with` / `prepend_mod_with` |

**Conclusión central**: el Flow Builder no necesita inventar una nueva capa de mensajería, ni un nuevo cliente HTTP para Meta, ni un nuevo intérprete de variables. Necesita **un nuevo motor de ejecución de estado** (`FlowRun` avanzando nodo a nodo) que se conecta a estas piezas ya existentes como "puntos de enganche".

**Brecha real encontrada**: hoy, cuando un usuario de WhatsApp toca un botón interactivo o selecciona una opción de una lista, Chatwoot solo guarda el **texto del título** del botón como cuerpo del mensaje; el `id`/payload del botón (el valor "de máquina") **se descarta** (`incoming_message_service_helpers.rb`, con un TODO explícito en el código: *"map interactive messages back to button messages in chatwoot"*). Esto es crítico para el Flow Builder, porque el nodo `WHATSAPP_BUTTONS` necesita bifurcar según qué botón exacto se pulsó, no según el texto (que puede repetirse o traducirse). Ver sección 4.

## 2. Flujo actual documentado

### 2.1 Entrada (META → Chatwoot)

```
Meta (WhatsApp Cloud API)
  │  POST webhook (firmado HMAC-SHA256, X-Hub-Signature-256)
  ▼
Webhooks::WhatsappController#process_payload
  - verifica firma (MetaTokenVerifyConcern)
  - resuelve Channel::Whatsapp por (display_phone_number, phone_number_id)
  - descarta si el número está en INACTIVE_WHATSAPP_NUMBERS
  ▼
Webhooks::WhatsappEventsJob (Sidekiq, MutexApplicationJob)
  - lock Redis por (inbox_id, sender_id) → evita condiciones de carrera
    (p.ej. álbumes con varios adjuntos llegando en webhooks paralelos)
  - separa eventos "messages" vs "smb_message_echoes" (coexistencia)
  - dispatcha a Whatsapp::IncomingMessage(WhatsappCloud)Service
  ▼
Whatsapp::IncomingMessageBaseService
  - dedupe por wamid (source_id) + Whatsapp::MessageDedupLock (Redis SET NX)
  - resuelve/crea Contact + ContactInbox
  - resuelve/crea Conversation (respeta lock_to_single_conversation)
  - crea Message (message_type: incoming)
    - texto: message.dig(:text, :body)
    - botón (legacy quick reply): message.dig(:button, :text)
    - botón interactivo: message.dig(:interactive, :button_reply, :title)  ← SOLO título
    - lista interactiva:        message.dig(:interactive, :list_reply, :title) ← SOLO título
  ▼
Conversation / Message persistidos
  ▼
Dispatcher.dispatch('message.created', ...)  → listeners síncronos + asíncronos
  (AgentBotListener, AutomationRuleListener, WebhookListener, ActionCableListener, ...)
```

### 2.2 Salida (Chatwoot → META)

```
Algo crea un Message saliente (agente humano, AutomationRule, AgentBot, futuro FlowEngine)
  ▼
Message#save → after_create → SendReplyJob.perform_later(message.id)
  ▼
SendReplyJob
  - CHANNEL_SERVICES['Channel::Whatsapp'] → Whatsapp::SendOnWhatsappService
  ▼
Base::SendOnChannelService (valida canal, filtra notas privadas/eco/voz)
  ▼
Whatsapp::SendOnWhatsappService#perform_reply
  - si hay template_params o la ventana de 24h está cerrada → send_template_message
  - si no → send_session_message
  ▼
Channel::Whatsapp#send_message / #send_template  (delegate a provider_service)
  ▼
Whatsapp::Providers::WhatsappCloudService
  - texto simple → send_text_message
  - adjuntos      → send_attachment_message
  - plantilla     → send_template  (vía Whatsapp::TemplateProcessorService)
  - content_type == 'input_select' → send_interactive_text_message
      (botones si ≤3 items, lista si >3 items — BaseService#create_payload_based_on_items)
  ▼
Graph API de Meta → guarda wamid devuelto en message.source_id
```

### 2.3 Automatización existente (referencia para el motor de flujos)

```
Evento de dominio (conversation.created, message.created, conversation.status_changed, ...)
  ▼
Rails.configuration.dispatcher.dispatch(EVENT, time, data)   [patrón Wisper]
  ├── SyncDispatcher   → ActionCableListener, AgentBotListener
  └── AsyncDispatcher  → EventDispatcherJob (Sidekiq)
        → AutomationRuleListener, WebhookListener, CampaignListener, ...
  ▼
AutomationRuleListener
  - filtra performed_by_automation?(event) → evita bucles infinitos
    (Current.executed_by se propaga como performed_by en cada evento)
  - AutomationRules::ConditionsFilterService → evalúa conditions (jsonb) contra SQL
  - si matchea → AutomationRules::ActionService.new(rule, account, conversation).perform
      - itera actions (jsonb), cada action_name → método (add_label, assign_team,
        assign_agent, change_status, send_message, send_webhook_event, ...)
      - cada acción aislada con rescue + ChatwootExceptionTracker
```

Este es el patrón más cercano a lo que necesita el motor de flujos, con una diferencia clave: `AutomationRule` es **stateless** (evalúa condiciones y ejecuta acciones de una sola vez, en un solo "tick"), mientras que un `FlowRun` es **stateful** (avanza nodo por nodo a través de múltiples eventos/mensajes, pudiendo pausarse esperando la respuesta del usuario). Por eso el motor de flujos necesita una tabla de estado persistente (`flow_runs`) que `AutomationRule` no necesita.

## 3. Qué reutilizar vs qué NO duplicar

**Reutilizar directamente (sin envolver ni reimplementar):**
- Envío de mensajes: crear un `Message` y dejar que `SendReplyJob` lo entregue. No crear un cliente Graph API propio.
- Envío de botones/listas: usar `content_type: 'input_select'` + `content_attributes[:items]`. No reinventar el payload interactivo de Meta.
- Plantillas: usar `Channel::Whatsapp#message_templates` (ya sincronizadas) + `additional_attributes['template_params']`. No duplicar el catálogo de plantillas.
- Interpolación `{{...}}`: usar `Liquid::Template.parse(...).render(drops)` con Drops nuevos (`FlowRunDrop`) siguiendo `Liquidable`. No escribir un parser de variables a mano.
- Bus de eventos: engancharse a `Dispatcher`/`Events::Types` con un nuevo listener. No poner callbacks `after_create` propios en `Message`/`Conversation`.
- Autorización: Pundit + `Current.account.flow_definitions`. No inventar un sistema de permisos paralelo.
- Handoff: `Conversation#assignee_agent_bot_id`/`#assignee_id`, `bot_handoff!`, cambio de estado/equipo/etiqueta ya existentes vía `ActionService`.
- Locking: patrón token + `Redis::Alfred.delete_if_equals` (compare-and-delete atómico) de `AutoAssignment::AssignmentJob`, no el `Redis::LockManager` simple (documentado como no seguro ante robo de lock).
- Validación de jsonb: `JsonSchemaValidator` (JSONSchemer) ya existente, no un validador custom.
- Extensión Enterprise: `prepend_mod_with`/`include_mod_with`.

**Construir nuevo (no existe hoy):**
- Motor de ejecución con estado por conversación (`FlowRun` avanzando nodo a nodo).
- Persistencia de la definición visual (grafo de nodos/edges).
- Registry de `FlowNodeHandler` por tipo de nodo.
- Editor visual de nodos en el frontend (no existe ninguna librería de node-graph en `package.json`; solo `vuedraggable`, que es para reordenar listas, no para canvas libre con zoom/pan/conexiones). Se recomienda añadir `@vue-flow/core` (Vue 3 nativo).
- Persistencia del `id`/payload de botones interactivos recibidos (ver brecha, sección 4).
- Adapter HTTP con allowlist/SSRF para el nodo `HTTP_REQUEST` (no existe un mecanismo equivalente reutilizable hoy — `SafeFetch` existe para webhooks salientes pero habría que revisar si cubre el caso de HTTP_REQUEST arbitrario configurado por el usuario final).

## 4. Brecha crítica: botones interactivos de WhatsApp

Archivo: `app/services/whatsapp/incoming_message_service_helpers.rb`

```ruby
message.dig(:text, :body) ||
message.dig(:button, :text) ||
message.dig(:interactive, :button_reply, :title) ||
message.dig(:interactive, :list_reply, :title) ||
message.dig(:name, :formatted_name)
# TODO: map interactive messages back to button messages in chatwoot
```

Meta envía también `interactive.button_reply.id` / `interactive.list_reply.id` (el valor que Chatwoot mismo definió al enviar el botón, vía `content_attributes[:items][].value`), pero Chatwoot **no lo guarda** en ningún lado — solo persiste el título visible.

**Impacto en Flow Builder**: el nodo `WHATSAPP_BUTTONS` debe poder conectar cada botón a una rama distinta del flujo de forma determinista. Si solo se dispone del título (que puede cambiar de idioma, tener espacios, mayúsculas distintas, etc.), el matching es frágil.

**Recomendación** (para Etapa 8, no ahora): extender `create_regular_message`/`message_content_attributes` en `incoming_message_base_service.rb` para persistir `content_attributes[:submitted_values] = { id: ..., title: ... }` cuando el mensaje entrante sea `interactive.button_reply`/`interactive.list_reply`, siguiendo el mismo patrón ya usado para `in_reply_to_external_id` y `referral`. Esto es un cambio quirúrgico, aditivo, y no rompe nada existente (solo añade una clave a un jsonb).

## 5. Proyecto de referencia externo: `chatwoot-power-tools`

Se revisó el README de <https://github.com/achiya-automation/chatwoot-power-tools>. Hallazgos:

- Es una **aplicación sidecar separada** (SPA Vue montada en `/chatwoot-addons/*`, con su propio esquema/rol de PostgreSQL `drip_engine`, contenedor Docker propio `cwpt-engine`), que habla con Chatwoot **solo a través de su API REST pública**.
- Esto es exactamente el patrón que la especificación del proyecto **prohíbe explícitamente** ("NO quiero crear una aplicación externa"). No es una plantilla arquitectónica válida para este proyecto tal cual.
- **Sí es útil como referencia de vocabulario de nodos**: sus 10 tipos de nodo (trigger, message, whatsapp template, question, buttons, condition, delay, action, webhook, handoff) validan que el conjunto de nodos propuesto en la especificación (más amplio: añade `SET_VARIABLE`, `AI`, `WHATSAPP_FLOW`, gestión de etiquetas/equipo/agente/contacto) es razonable y cubre casos reales de producción.
- Detalles operativos que vale la pena tener en cuenta como inspiración de producto (no de arquitectura): pausar automáticamente por horario/festivos, límites de calidad/plantillas de Meta como corte automático de envío, detección de opt-out en lenguaje natural, y namespacing claro de sus tablas (`drip.*`) para no chocar con las tablas núcleo de Chatwoot — este último punto sí aplica directamente: nuestras tablas nuevas deben tener nombres claramente namespaced (`flow_*`) y no tocar tablas existentes.
- Limitación relevante que confirma una decisión de diseño nuestra: dependen de `campaign_recipients` (tabla núcleo) solo para *lectura* de resultados de campaña — es decir, incluso un proyecto externo evita escribir en tablas núcleo de Chatwoot, reforzando la regla del proyecto de "preferir tablas nuevas".

## 6. Riesgos identificados

1. **Doble ejecución de nodos** ante mensajes concurrentes (dos webhooks casi simultáneos para la misma conversación). Mitigación: lock Redis por `flow_run_id`/`conversation_id` con patrón token+compare-and-delete, re-chequeo de estado dentro del lock (ver `docs/flow-builder-architecture.md`).
2. **Bucles infinitos**: un flujo que envía un mensaje puede volver a disparar su propio trigger. Mitigación: reutilizar `Current.executed_by`/`performed_by` como ya hace `AutomationRule`.
3. **Definiciones de flujo que cambian mientras hay ejecuciones en curso**: un `FlowRun` en progreso no debe romperse si alguien edita el flujo. Mitigación: cada `FlowRun` debe referenciar una versión inmutable del grafo (snapshot), no el registro editable en vivo.
4. **SSRF en el nodo `HTTP_REQUEST`**: debe reutilizar/extender los controles de red interna ya existentes en el proyecto (revisar `SafeFetch` y la variable de entorno `SAFE_FETCH_ALLOW_PRIVATE_NETWORK` vista en el proyecto de referencia) y añadir allowlist configurable por cuenta.
5. **Nodo `AI` ejecutando acciones no controladas**: la especificación exige que la IA nunca ejecute SQL/HTTP/código directamente — debe pasar siempre por los mismos `FlowNodeHandler`s autorizados que cualquier otro nodo.
6. **Multi-tenant**: todas las tablas nuevas requieren `account_id` obligatorio + índice, y todo acceso vía `Current.account.flow_definitions` (nunca `FlowDefinition.find` a secas), replicando la convención ya usada en todo el proyecto.

## 7. Próximos documentos

- `docs/flow-builder-architecture.md` — diseño de capas, Registry/Handler, motor de ejecución, integración con canales, concurrencia, seguridad.
- `docs/flow-builder-data-model.md` — esquema de tablas propuesto y justificación frente a convenciones existentes.

Ningún cambio de código se realiza en esta fase.
