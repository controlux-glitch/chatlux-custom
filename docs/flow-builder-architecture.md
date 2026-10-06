# Flow Builder — Diseño de arquitectura propuesto (Fase 1)

> Estado: **propuesta de diseño, sin implementar**. Basado en `docs/flow-builder-analysis.md`.
> Principio rector: REUTILIZAR > EXTENDER > CREAR.

## 1. Vista de capas

```
┌─────────────────────────────────────────────────────────────────┐
│ FRONTEND (Vue 3, dentro del dashboard existente)                 │
│                                                                   │
│  /flows            → FlowsIndexPage.vue      (lista)             │
│  /flows/new        → FlowEditorPage.vue      (canvas, nuevo)     │
│  /flows/:id        → FlowEditorPage.vue      (canvas, edición)   │
│  /flows/:id/runs   → FlowRunsPage.vue        (observabilidad)    │
│                                                                   │
│  Editor visual: @vue-flow/core (nuevo dependency)                │
│  Solo produce/edita JSON { nodes[], edges[] } — no ejecuta nada  │
└───────────────────────────┬───────────────────────────────────--─┘
                             │ REST API (Current.account scoped)
┌───────────────────────────▼───────────────────────────────────--─┐
│ BACKEND — API / Persistencia                                     │
│                                                                   │
│  Api::V1::Accounts::FlowsController        (CRUD + publish)      │
│  Api::V1::Accounts::FlowRunsController     (solo lectura)        │
│  FlowDefinitionPolicy (Pundit, igual que AutomationRulePolicy)   │
│  Modelos: FlowDefinition, FlowDefinitionInbox, FlowRun,          │
│           FlowRunEvent                                           │
└───────────────────────────┬──────────────────────────────────---─┘
                             │
┌───────────────────────────▼───────────────────────────────────--─┐
│ BACKEND — Disparo (Trigger)                                      │
│                                                                   │
│  FlowEngineListener (nuevo, se suscribe a AsyncDispatcher junto   │
│  a AutomationRuleListener) escucha:                               │
│    message_created, conversation_created, conversation_updated   │
│                                                                   │
│  - descarta si performed_by_automation?(event) (anti-loop)       │
│  - busca FlowRun activo para la conversación → si existe,        │
│    encola FlowEngine::AdvanceJob (resume)                         │
│  - si no existe, evalúa FlowDefinitions publicados con trigger    │
│    TRIGGER matching (inbox, keyword, nueva conversación...) →     │
│    crea FlowRun y encola FlowEngine::AdvanceJob (start)           │
└───────────────────────────┬───────────────────────────────────--─┘
                             │
┌───────────────────────────▼───────────────────────────────────--─┐
│ BACKEND — Motor de ejecución (independiente del editor)          │
│                                                                   │
│  FlowEngine::AdvanceJob (Sidekiq, MutexApplicationJob)            │
│    - lock Redis: FLOW_RUN_MUTEX::<flow_run_id> (token +           │
│      compare-and-delete, igual que AutoAssignment::AssignmentJob) │
│    - re-chequea estado del FlowRun dentro del lock (idempotencia) │
│    - FlowEngine::Runner.new(flow_run).advance                     │
│                                                                   │
│  FlowEngine::Runner                                               │
│    - resuelve el nodo actual desde el snapshot jsonb del run      │
│    - FlowEngine::NodeHandlerRegistry.for(node.type)                │
│    - handler.execute(context, node) → NodeResult                  │
│    - registra FlowRunEvent (entrada/salida/duración/error)         │
│    - decide next_node_id según NodeResult (edge normal, edge por   │
│      condición, o "esperar input" → status: waiting_input)         │
└───────────────────────────┬───────────────────────────────────--─┘
                             │
┌───────────────────────────▼───────────────────────────────────--─┐
│ BACKEND — Node Handlers (Registry/Handler, NO switch gigante)     │
│                                                                   │
│  FlowEngine::NodeHandlerRegistry.register('MESSAGE', MessageNodeHandler)
│  ... uno por cada tipo (ver sección 3)                            │
│                                                                   │
│  Cada handler reutiliza servicios existentes:                     │
│   - MessageNodeHandler        → crea Message (SendReplyJob se     │
│                                  encarga de la entrega real)       │
│   - WhatsappButtonsNodeHandler→ Message content_type input_select │
│   - WhatsappTemplateNodeHandler→ additional_attributes[template_params]
│   - ConditionNodeHandler      → evalúa contra FlowRun#variables    │
│   - SetVariableNodeHandler    → escribe en FlowRun#variables       │
│   - HttpRequestNodeHandler    → HTTP con allowlist/SSRF guard      │
│   - AiNodeHandler             → FlowEngine::AIProvider (interfaz)  │
│   - AddLabel/RemoveLabel/AssignTeam/AssignAgent/                   │
│     UpdateContact/ChangeStatus → delegan a ActionService existente │
│   - HumanHandoffNodeHandler   → Conversation#bot_handoff! + acciones│
│   - DelayNodeHandler          → re-encola AdvanceJob con `wait:`   │
│   - EndNodeHandler            → status: completed                  │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Motor de ejecución: contrato

```ruby
# Interfaz que implementa cada handler (Registry/Handler, no switch)
module FlowEngine
  class NodeHandler
    def execute(context, node)
      raise NotImplementedError
    end
  end
end
```

- `context` = objeto de valor con `flow_run`, `conversation`, `contact`, `account`, `inbox`, y acceso a variables interpoladas vía Liquid (`context.render(node.params)`).
- `node` = hash del snapshot jsonb (`{id, type, params, ...}`), **no** un ActiveRecord — el motor de ejecución nunca depende del editor visual ni de cómo se dibujó el nodo.
- Retorno: `NodeResult` con:
  - `status`: `:continue` | `:wait_input` | `:end` | `:error`
  - `next_node_id`: id del siguiente nodo (resuelto por el handler o por `Runner` según edges), o `nil` en `:wait_input`/`:end`
  - `variables_patch`: hash a mergear en `flow_run.variables`
  - `error`: mensaje si `:error`

`FlowEngine::NodeHandlerRegistry` es un simple `Hash[String, Class]` poblado en un initializer (`config/initializers/flow_engine.rb`), igual de simple que `SendReplyJob::CHANNEL_SERVICES`. Añadir un nuevo tipo de nodo = registrar una clase, sin tocar el `Runner`.

## 3. Disparo (trigger) y reanudación — el punto más delicado

El reto central frente a `AutomationRule` (que es stateless) es que un `FlowRun` puede quedar **esperando** una respuesta del usuario (nodo `QUESTION` o `WHATSAPP_BUTTONS`). Esto requiere:

1. Cuando `FlowRun.status == 'waiting_input'`, el siguiente `message.created` de esa conversación **no** debe re-evaluar triggers de otros flujos — debe **reanudar** el `FlowRun` existente, tratando el contenido del mensaje entrante como la respuesta.
2. `FlowEngineListener` debe comprobar primero si hay un `FlowRun` activo (`running`/`waiting_input`) para `conversation_id` antes de evaluar nuevos triggers — análogo a cómo `Conversation` ya evita re-abrir bots cuando hay un agente humano asignado.
3. Para el nodo `WHATSAPP_BUTTONS`, la reanudación debe idealmente matchear por el `id` del botón (ver brecha de la sección 4 del análisis), con fallback al texto si el `id` no está disponible (mensajes antiguos o canales no-WhatsApp).

```
message.created (conversation X)
  │
  ▼
FlowEngineListener#message_created
  │
  ├─ performed_by_automation?(event) ? → skip (anti-loop)
  │
  ├─ FlowRun.active.find_by(conversation_id: X) existe?
  │     SÍ → FlowEngine::AdvanceJob.perform_later(flow_run.id, resume_message_id: message.id)
  │     NO → evaluar FlowDefinitions publicados con TRIGGER que matchee
  │          (inbox, palabra clave, nueva conversación) →
  │          crear FlowRun (status: running, current_node: nil) →
  │          FlowEngine::AdvanceJob.perform_later(flow_run.id)
```

## 4. Concurrencia e idempotencia

Reutilizando el patrón de `app/jobs/auto_assignment/assignment_job.rb` (token + compare-and-delete), en vez del `Redis::LockManager` simple:

```ruby
class FlowEngine::AdvanceJob < MutexApplicationJob
  def perform(flow_run_id, **opts)
    token = SecureRandom.uuid
    key = format(Redis::RedisKeys::FLOW_RUN_MUTEX, flow_run_id: flow_run_id)
    return unless Redis::Alfred.set(key, token, nx: true, ex: 30)

    begin
      flow_run = FlowRun.find(flow_run_id)
      return if flow_run.completed? || flow_run.failed? # re-chequeo dentro del lock
      FlowEngine::Runner.new(flow_run).advance(**opts)
    ensure
      Redis::Alfred.delete_if_equals(key, token)
    end
  end
end
```

- El TTL del lock (30s) más `retry_on_lock_conflict` cubre el caso de dos mensajes casi simultáneos.
- El re-chequeo de estado *dentro* del lock (patrón `Campaign#mark_processing!`) es lo que realmente garantiza que un nodo no se ejecute dos veces, no el lock por sí solo.
- Nodos que impliquen espera (`DELAY`) usan `AdvanceJob.set(wait: n).perform_later(...)`, nunca `sleep`.

## 5. Integración con canales (WhatsApp Cloud API y futuros)

No se crea ningún cliente HTTP nuevo hacia Meta. Los handlers de envío **siempre** construyen un `Message` de Chatwoot y dejan que la tubería existente lo entregue:

```
MessageNodeHandler#execute
  → Messages::MessageBuilder (o Message.create! directamente, según lo que ya usa
    el resto del código para crear mensajes salientes desde automatización)
  → (Message#save dispara automáticamente SendReplyJob)
  → SendReplyJob → CHANNEL_SERVICES[channel.class] → Whatsapp::SendOnWhatsappService
  → ... (sin cambios)
```

Esto es lo que ya pide la especificación como `ChannelMessageAdapter` con implementaciones por canal — **ya existe** como `Base::SendOnChannelService` + `SendReplyJob::CHANNEL_SERVICES`. No se necesita crear una abstracción nueva; el Flow Builder simplemente la consume, igual que Automation/Macros ya lo hacen a través de `ActionService#send_message`.

Para `WHATSAPP_BUTTONS`: el handler construye `Message.new(content_type: 'input_select', content_attributes: { items: [{title:, value:}, ...] })`. Cada `value` es el id que luego debe usarse para bifurcar en la reanudación (una vez cerrada la brecha descrita en el análisis).

Para `WHATSAPP_TEMPLATE`: el handler solo selecciona una plantilla ya sincronizada (`channel.message_templates`) y arma `additional_attributes['template_params']`, reutilizando `Whatsapp::TemplateProcessorService`.

`WHATSAPP_FLOW` (WhatsApp Flows de Meta) se deja como **stub de interfaz** en esta fase: un `NodeHandler` con un `TODO` documentado, sin implementación real, para no bloquear el resto del roadmap. Se mantiene conceptualmente separado del "Flow Builder de Chatwoot" (que es el editor de automatización nativo), tal como exige la especificación.

## 6. Variables

- Fuente única de verdad: Liquid, igual que `Liquidable`.
- `FlowEngine::VariableContext` construye el hash de drops:
  - sistema: `flow_run` (nuevo `FlowRunDrop`: id, status, started_at...)
  - contacto: reutiliza `ContactDrop`
  - conversación: reutiliza `ConversationDrop`
  - variables custom del run: expuestas como drop plano desde `flow_run.variables` (jsonb)
- `SET_VARIABLE` node handler simplemente hace `flow_run.variables.merge!(key => interpolated_value)` y persiste.
- `HTTP_REQUEST` mapea la respuesta a variables con la misma convención (`api.status`, `api.importe` → claves dentro de `flow_run.variables['api']`).

## 7. HTTP_REQUEST — seguridad

- Reutilizar cualquier mecanismo de `SafeFetch` ya presente en el proyecto para llamadas salientes (usado por `Webhooks::Trigger`); si `SafeFetch` no cubre URLs arbitrarias configuradas por el usuario final, extenderlo con:
  - Resolución DNS + bloqueo de rangos privados/loopback/link-local (SSRF) — comportamiento por defecto, solo desactivable explícitamente por variable de entorno a nivel instalación (igual que `SAFE_FETCH_ALLOW_PRIVATE_NETWORK` observado en el proyecto de referencia externo).
  - Allowlist de dominios opcional configurable por cuenta.
  - Timeout obligatorio (default corto, p.ej. 10s) y límite de tamaño de respuesta.
- El nodo nunca ejecuta código arbitrario ni permite `eval` sobre la respuesta; solo mapeo declarativo `json_path → variable`.

## 8. Nodo AI

```ruby
module FlowEngine
  module AIProvider
    class Base
      def classify_intent(text, options:); end
      def extract_fields(text, schema:); end
      def generate_reply(prompt, context:); end
    end
  end
end

module FlowEngine
  module AIProvider
    class OpenAI < Base
      # implementación concreta
    end
  end
end
```

- `AiNodeHandler` solo puede:
  1. Clasificar intención → escribir el resultado en una variable (`{{intent}}`), y dejar que un `ConditionNodeHandler` posterior decida la rama.
  2. Extraer campos → escribir variables.
  3. Generar texto de respuesta → pasarlo a un `MessageNodeHandler` interno (no enviar directamente desde el nodo AI).
- El nodo AI **nunca** llama directamente a `HttpRequestNodeHandler` ni ejecuta SQL. Cualquier acción posterior pasa por su propio nodo/handler autorizado, cumpliendo el requisito de la especificación.

## 9. Handoff

`HumanHandoffNodeHandler#execute`:
```ruby
conversation.update!(status: :open) # o el que corresponda
conversation.bot_handoff! # ya dispara CONVERSATION_BOT_HANDOFF
ActionService.new(...).assign_team([team_id]) if team_id
ActionService.new(...).assign_agent([agent_id]) if agent_id
ActionService.new(...).add_label([label]) if label
flow_run.update!(status: :handed_off, finished_at: Time.current)
```
Todo reutilizado de `ActionService`/`Conversation`, sin lógica de asignación nueva.

## 10. Seguridad multi-tenant

- Todas las tablas nuevas llevan `account_id` obligatorio + índice.
- Todo acceso desde controladores vía `Current.account.flow_definitions` / `Current.account.flow_runs` (nunca `FlowDefinition.find` a secas), igual que el resto del proyecto.
- `FlowDefinitionPolicy` y `FlowRunPolicy` siguen el patrón minimalista de `AutomationRulePolicy`/`WebhookPolicy` (`@account_user.administrator?`), ajustable después si se decide permitir rol `agent`.
- `FlowEngine::AdvanceJob` recibe `flow_run_id`; el primer paso del `Runner` **siempre** revalida `flow_run.account_id == flow_run.conversation.account_id` antes de tocar nada (defensa en profundidad, no solo confiar en el scoping del enqueue).

## 11. Extensión Enterprise

- `FlowDefinition.prepend_mod_with('FlowDefinition')` y equivalente en modelos/servicios clave, siguiendo el patrón ya usado por `AutomationRule`, `AgentBot`, `Whatsapp::Providers::WhatsappCloudService`.
- Si algún tipo de nodo es exclusivo Enterprise (p.ej. `AI` con proveedor propietario), el registro del handler puede condicionarse vía `ChatwootApp.enterprise?` en el initializer, sin bifurcar el `Runner`.

## 12. Frontend

- Nueva sección `FLUJOS` en el sidebar (`components-next/sidebar/Sidebar.vue`), como entrada simple (sin hijos), gateada por `meta: { featureFlag: FEATURE_FLAGS.FLOWS, permissions: ['administrator'] }` en la ruta — el sidebar ya resuelve el gating automáticamente vía `Policy`, sin código adicional en `Sidebar.vue`.
- Rutas top-level (`flows.routes.js`, registradas en `dashboard.routes.js`, igual que `campaigns.routes.js`), no anidadas bajo `settings/`, porque el editor necesita una página completa (canvas), no un modal.
- Editor: `@vue-flow/core` (única librería de node-graph compatible con Vue 3; no existe ninguna en el proyecto hoy — se confirmó que `vuedraggable` solo reordena listas).
- El editor **solo** serializa `{ nodes: [...], edges: [...] }` a la API — nunca ejecuta lógica de flujo en el navegador. El guardado automático (`autosave`) hace `PATCH /flows/:id` con debounce, siguiendo el patrón de otros formularios del dashboard.
- Componentes bajo `components-next/Flows/...`, i18n bajo `i18n/locale/en/flows.json` con clave raíz `FLOWS`, agregado en `i18n/locale/en/index.js`.

## 13. Resumen de nuevas piezas backend

| Pieza | Tipo | Reutiliza |
|---|---|---|
| `FlowDefinition`, `FlowDefinitionInbox` | Modelo | `Channelable`/`AgentBotInbox` como referencia de asociación a inbox |
| `FlowRun`, `FlowRunEvent` | Modelo | jsonb + `JsonSchemaValidator` |
| `Api::V1::Accounts::FlowsController` | Controlador | Mismo patrón que `AutomationRulesController` |
| `Api::V1::Accounts::FlowRunsController` | Controlador | Solo lectura, mismo patrón |
| `FlowDefinitionPolicy`, `FlowRunPolicy` | Pundit | `AutomationRulePolicy` |
| `FlowEngineListener` | Listener (Wisper) | `AutomationRuleListener` |
| `FlowEngine::AdvanceJob` | Sidekiq Job | `MutexApplicationJob` + `AutoAssignment::AssignmentJob` (locking) |
| `FlowEngine::Runner` | PORO | — (nuevo, pequeño y testeable) |
| `FlowEngine::NodeHandlerRegistry` + handlers | PORO | `SendReplyJob::CHANNEL_SERVICES` como inspiración de registry |
| `FlowEngine::VariableContext` + `FlowRunDrop` | PORO/Drop | `Liquidable`, Drops existentes |
| `FlowEngine::AIProvider::*` | PORO | ninguno directo (nuevo, aislado) |

Ver `docs/flow-builder-data-model.md` para el esquema de tablas propuesto.
