# Flow Builder — Modelo de datos propuesto (Fase 1)

> Estado: **propuesta**, sin migraciones creadas todavía. Nombres de tabla no definitivos hasta validar en Etapa 2.
> Convenciones seguidas: ver `db/migrate/*_create_calls.rb` como referencia de estilo (bigint FK manuales + `add_index`, sin `t.references`), y `automation_rules`/`webhooks` como referencia de scoping por `account_id`.

## 1. Decisión de diseño: jsonb vs tablas normalizadas para nodes/edges

La especificación sugiere conceptualmente `flow_nodes` y `flow_edges` como tablas separadas, pero pide explícitamente no asumir esos nombres y revisar antes las convenciones del proyecto.

**Convención existente dominante**: `AutomationRule` guarda `conditions` y `actions` — estructuras de "pasos" variables — como **columnas jsonb**, no como tablas normalizadas hijas. Esto es consistente en todo el código (también `additional_attributes`, `custom_attributes`, `bot_config`, `provider_config`).

**Decisión recomendada**: almacenar el grafo completo (`nodes[]` + `edges[]`) como **una sola columna jsonb** (`definition`) dentro de `flow_definitions`, en vez de tablas `flow_nodes`/`flow_edges` normalizadas.

Razones:
- Coherente con la convención dominante del proyecto (MVP, mínimo código, evitar abstracciones prematuras — `AGENTS.md`).
- El editor visual necesita leer/escribir el grafo completo de una vez (guardado automático de todo el canvas), no nodos individuales — una tabla normalizada obligaría a diffs complejos en cada autosave.
- Permite versionado simple: cada publicación (`publish`) puede snapshotear `definition` completa en un `FlowVersion`/columna `published_definition`, sin migrar filas de nodos/edges.
- Validación estructural vía `JsonSchemaValidator` (ya existente en el proyecto) en vez de constraints SQL.
- Es más fácil de extender (nuevos campos por tipo de nodo) sin migraciones.

Trade-off aceptado: no se pueden hacer queries SQL directas tipo "todos los nodos de tipo X en cualquier flujo" sin iterar jsonb. Esto no es un requisito de la especificación (la observabilidad se resuelve con `flow_run_events`, que sí es tabla normalizada — ver abajo). Si en el futuro se necesita indexar nodos, se puede añadir un índice GIN sobre `definition` sin cambiar el modelo.

**Lo que sí es tabla normalizada** (porque se consulta, filtra y ordena constantemente, igual que cualquier recurso de negocio en Chatwoot): `flow_runs` y `flow_run_events`.

## 2. Esquema propuesto

### 2.1 `flow_definitions`

```ruby
create_table :flow_definitions do |t|
  t.bigint  :account_id,   null: false
  t.bigint  :created_by_id            # user que lo creó
  t.bigint  :updated_by_id            # user que lo editó por última vez
  t.string  :name,         null: false
  t.text    :description
  t.integer :status,       null: false, default: 0  # enum: draft: 0, published: 1, disabled: 2
  t.jsonb   :definition,   null: false, default: { nodes: [], edges: [] }
  t.jsonb   :published_definition     # snapshot inmutable de la última publicación
  t.integer :version,      null: false, default: 0   # incrementa en cada publish
  t.datetime :published_at
  t.timestamps
end

add_index :flow_definitions, :account_id
add_index :flow_definitions, [:account_id, :status]
```

- `definition` = borrador editable en vivo (lo que edita el canvas).
- `published_definition` + `version` = snapshot congelado que usan los `FlowRun` en curso, para que editar un flujo publicado no rompa ejecuciones activas (ver riesgo #3 del análisis).
- `status`: `draft` (no dispara ejecuciones), `published` (dispara), `disabled` (publicado antes, pausado manualmente — igual semántica que `AutomationRule#active`, mirar convención exacta de enum usada allí antes de nombrar).

Forma de `definition` (JSON, no código ejecutable):
```json
{
  "nodes": [
    { "id": "n1", "type": "TRIGGER", "position": {"x":0,"y":0}, "params": {"trigger_type": "new_conversation", "inbox_ids": [3]} },
    { "id": "n2", "type": "MESSAGE", "position": {"x":0,"y":150}, "params": {"content": "Hola {{contact.name}}"} },
    { "id": "n3", "type": "WHATSAPP_BUTTONS", "position": {"x":0,"y":300}, "params": {"text": "¿En qué te ayudo?", "buttons": [{"id":"billing","title":"Facturación"},{"id":"support","title":"Soporte"}]} }
  ],
  "edges": [
    { "id": "e1", "source": "n1", "target": "n2" },
    { "id": "e2", "source": "n2", "target": "n3" },
    { "id": "e3", "source": "n3", "target": "n4", "source_handle": "billing" },
    { "id": "e4", "source": "n3", "target": "n5", "source_handle": "support" }
  ]
}
```
`source_handle` permite que un nodo con múltiples salidas (`CONDITION`, `WHATSAPP_BUTTONS`) conecte cada salida a un nodo distinto — el `Runner` resuelve `next_node_id` buscando el edge cuyo `source == current_node.id && source_handle == resultado_del_handler`.

### 2.2 `flow_definition_inboxes`

Join table, mismo patrón que `agent_bot_inboxes` (incluyendo `before_validation :ensure_account_id`):

```ruby
create_table :flow_definition_inboxes do |t|
  t.bigint  :account_id,         null: false
  t.bigint  :flow_definition_id, null: false
  t.bigint  :inbox_id,           null: false
  t.integer :status, null: false, default: 0  # active: 0, inactive: 1
  t.timestamps
end

add_index :flow_definition_inboxes, :account_id
add_index :flow_definition_inboxes, [:flow_definition_id, :inbox_id], unique: true
add_index :flow_definition_inboxes, :inbox_id
```

Permite que un flujo aplique a uno o varios inboxes (igual que un `AgentBot` puede atarse a varios).

### 2.3 `flow_runs`

```ruby
create_table :flow_runs do |t|
  t.bigint  :account_id,         null: false
  t.bigint  :flow_definition_id, null: false
  t.integer :flow_version,       null: false   # copia de flow_definitions.version al momento de iniciar
  t.bigint  :conversation_id,    null: false
  t.bigint  :contact_id,         null: false
  t.bigint  :inbox_id,           null: false
  t.string  :current_node_id               # id del nodo actual dentro del snapshot (no FK)
  t.integer :status, null: false, default: 0
    # enum: running: 0, waiting_input: 1, completed: 2, failed: 3, cancelled: 4, handed_off: 5
  t.jsonb   :variables, null: false, default: {}
  t.jsonb   :definition_snapshot, null: false  # copia de published_definition al iniciar (inmutable)
  t.text    :error_message
  t.datetime :started_at,  null: false
  t.datetime :updated_at,  null: false
  t.datetime :finished_at
end

add_index :flow_runs, :account_id
add_index :flow_runs, :flow_definition_id
add_index :flow_runs, :conversation_id
add_index :flow_runs, :contact_id
add_index :flow_runs, [:account_id, :status]
# Solo una ejecución activa por conversación a la vez:
add_index :flow_runs, :conversation_id, unique: true,
  where: "status IN (0, 1)", name: 'index_flow_runs_on_active_conversation'
```

- `definition_snapshot` duplica el JSON del grafo en el propio run — parece redundante con `flow_definitions.published_definition`, pero es importante: si el `FlowDefinition` se **elimina** o se **despublica una nueva versión** mientras el run sigue activo, el run no debe fallar buscando una versión que ya no existe. Es el mismo criterio que llevó a copiar `flow_version` como número.
- El índice único parcial (`WHERE status IN (running, waiting_input)`) es la garantía a nivel de base de datos (además del lock Redis) de que nunca hay dos `FlowRun` activos simultáneos para la misma conversación — defensa en profundidad barata.
- `variables` acumula: variables de sistema calculadas al vuelo (no se persisten, se resuelven vía Liquid Drops en tiempo real), variables de contacto/conversación (tampoco se copian aquí, se leen en vivo vía Drops), y variables propias del flujo (`SET_VARIABLE`, respuestas de `QUESTION`, resultados de `HTTP_REQUEST`/`AI`) — estas sí se persisten aquí porque son estado del run, no del contacto/conversación.

No se crea una tabla `flow_run_variables` separada: seguiría el mismo antipatrón que se evitó con `flow_nodes`/`flow_edges` (normalizar algo que se lee/escribe siempre como conjunto completo, nunca fila por fila). Si en el futuro se necesita auditar el historial de cambios de una variable específica, ese historial ya queda cubierto por `flow_run_events` (cada evento de `SET_VARIABLE` registra su `output`).

### 2.4 `flow_run_events`

```ruby
create_table :flow_run_events do |t|
  t.bigint  :account_id,  null: false
  t.bigint  :flow_run_id, null: false
  t.string  :node_id,     null: false
  t.string  :node_type,   null: false
  t.jsonb   :input,       null: false, default: {}
  t.jsonb   :output,      null: false, default: {}
  t.integer :status,      null: false  # enum: success: 0, error: 1, waiting: 2
  t.text    :error_message
  t.string  :next_node_id
  t.integer :duration_ms
  t.datetime :created_at, null: false
end

add_index :flow_run_events, :account_id
add_index :flow_run_events, :flow_run_id
add_index :flow_run_events, [:flow_run_id, :created_at]
```

Cubre exactamente los campos que pide la especificación para la pantalla "Flow → Ejecuciones": nodo ejecutado (`node_id`/`node_type`), entrada (`input`), salida (`output`), resultado (`status`), duración (`duration_ms`), error (`error_message`), siguiente nodo (`next_node_id`).

No se usa `updated_at` (los eventos son inmutables, solo `created_at`) — coherente con el principio de "no defensive programming" / MVP.

## 3. Modelos Rails (resumen de asociaciones)

```ruby
class FlowDefinition < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  has_many :flow_definition_inboxes, dependent: :destroy_async
  has_many :inboxes, through: :flow_definition_inboxes
  has_many :flow_runs, dependent: :destroy_async

  enum status: { draft: 0, published: 1, disabled: 2 }

  validates :account_id, presence: true
  validates :name, presence: true
  validates_with JsonSchemaValidator, schema: FLOW_DEFINITION_SCHEMA,
                  attribute_resolver: ->(r) { r.definition }

  FlowDefinition.prepend_mod_with('FlowDefinition')
end

class FlowDefinitionInbox < ApplicationRecord
  belongs_to :account
  belongs_to :flow_definition
  belongs_to :inbox
  enum status: { active: 0, inactive: 1 }
  before_validation :ensure_account_id
  private
  def ensure_account_id
    self.account_id ||= inbox&.account_id
  end
end

class FlowRun < ApplicationRecord
  belongs_to :account
  belongs_to :flow_definition
  belongs_to :conversation
  belongs_to :contact
  belongs_to :inbox
  has_many :flow_run_events, dependent: :destroy_async

  enum status: { running: 0, waiting_input: 1, completed: 2, failed: 3, cancelled: 4, handed_off: 5 }

  scope :active, -> { where(status: [:running, :waiting_input]) }
end

class FlowRunEvent < ApplicationRecord
  belongs_to :account
  belongs_to :flow_run
  enum status: { success: 0, error: 1, waiting: 2 }
end
```

## 4. Qué NO se modifica en tablas existentes

Siguiendo la instrucción explícita de la especificación ("no modificar tablas existentes innecesariamente"), no se propone ningún `ALTER TABLE` sobre `conversations`, `contacts`, `messages`, `inboxes`. La única excepción potencial, documentada como *fuera del alcance de esta fase* y a decidir en Etapa 7-8, es la extensión aditiva de `messages.content_attributes` (columna jsonb ya existente, sin necesidad de migración) para persistir `submitted_values` en respuestas de botones interactivos — no requiere migración porque `content_attributes` ya es jsonb libre.

## 5. Enterprise

Ninguna de estas tablas necesita mirror en `enterprise/` — son tablas núcleo nuevas, no comportamiento específico de plan. Si en el futuro un tipo de nodo (p.ej. `AI` con proveedor propietario) es Enterprise-only, eso se resuelve a nivel de **registro de handler** (`FlowEngine::NodeHandlerRegistry`) condicionado por `ChatwootApp.enterprise?`, no con tablas separadas.

## 6. Próximo paso (Etapa 2, fuera de esta fase)

1. Validar los nombres de tabla propuestos contra cualquier convención de naming interna no cubierta en esta investigación (p.ej. si existe algún linter de nombres de tabla).
2. Escribir las migraciones Rails reales (`db/migrate/..._create_flow_definitions.rb`, etc.), sin ejecutarlas automáticamente.
3. Definir el JSON Schema exacto de `definition` (`FLOW_DEFINITION_SCHEMA`) para `JsonSchemaValidator`.
4. Definir Pundit policies (`FlowDefinitionPolicy`, `FlowRunPolicy`).

Ningún código ni migración se ha creado en esta fase.
