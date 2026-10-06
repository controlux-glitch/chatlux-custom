// Node type catalog for the visual editor palette and properties panel
// (Etapa 4: minimal set). Execution semantics for each type are implemented
// server-side by FlowEngine::NodeHandlerRegistry — see
// docs/flow-builder-architecture.md. `type` is the stable machine identifier
// persisted in flow_definitions.definition; `label`/`description` are the
// Spanish copy shown in the editor.
export const NODE_TYPE_DEFINITIONS = [
  {
    type: 'TRIGGER',
    label: 'Disparador',
    description: 'Inicia el flujo cuando ocurre un evento.',
    fields: [
      {
        key: 'trigger_type',
        label: 'Cuándo se activa',
        type: 'select',
        options: [
          { value: 'new_conversation', label: 'Nueva conversación' },
          { value: 'keyword', label: 'Palabra clave' },
        ],
      },
      {
        key: 'keyword',
        label: 'Palabra clave',
        type: 'text',
        placeholder: 'ej. hola',
      },
    ],
  },
  {
    type: 'MESSAGE',
    label: 'Enviar Mensaje',
    description: 'Envía un mensaje de texto al contacto.',
    fields: [
      {
        key: 'content',
        label: 'Contenido del mensaje',
        type: 'textarea',
        placeholder: 'Escribe el mensaje. Usa {{contact.name}} para variables.',
      },
    ],
  },
  {
    type: 'QUESTION',
    label: 'Hacer Pregunta',
    description: 'Envía una pregunta y guarda la respuesta en una variable.',
    fields: [
      { key: 'content', label: 'Pregunta', type: 'textarea' },
      {
        key: 'variable',
        label: 'Guardar respuesta en variable',
        type: 'text',
        placeholder: 'ej. nombre_cliente',
      },
    ],
  },
  {
    type: 'WHATSAPP_BUTTONS',
    label: 'Botones de WhatsApp',
    description:
      'Envía un mensaje con botones interactivos (máx. 3) o lista (más de 3).',
    fields: [
      { key: 'content', label: 'Texto del mensaje', type: 'textarea' },
      { key: 'buttons', label: 'Botones', type: 'buttons' },
    ],
  },
  {
    type: 'WHATSAPP_TEMPLATE',
    label: 'Plantilla de WhatsApp',
    description: 'Envía una plantilla previamente aprobada por Meta.',
    fields: [
      { key: 'template_name', label: 'Nombre de la plantilla', type: 'text' },
    ],
  },
  {
    type: 'WHATSAPP_FLOW',
    label: 'Flujo de WhatsApp (Meta)',
    description: 'Dispara un WhatsApp Flow oficial de Meta.',
    fields: [{ key: 'flow_id', label: 'ID del WhatsApp Flow', type: 'text' }],
  },
  {
    type: 'CONDITION',
    label: 'Condición',
    description: 'Evalúa una variable y bifurca el flujo.',
    fields: [
      {
        key: 'variable',
        label: 'Variable',
        type: 'text',
        placeholder: 'ej. {{intent}}',
      },
      {
        key: 'operator',
        label: 'Operador',
        type: 'select',
        options: [
          { value: 'equals', label: 'Es igual a' },
          { value: 'not_equals', label: 'Es distinto de' },
          { value: 'contains', label: 'Contiene' },
          { value: 'not_contains', label: 'No contiene' },
          { value: 'greater_than', label: 'Mayor que' },
          { value: 'less_than', label: 'Menor que' },
          { value: 'exists', label: 'Existe' },
          { value: 'not_exists', label: 'No existe' },
        ],
      },
      { key: 'value', label: 'Valor a comparar', type: 'text' },
    ],
  },
  {
    type: 'SET_VARIABLE',
    label: 'Guardar Variable',
    description: 'Guarda un valor en una variable del flujo.',
    fields: [
      { key: 'variable', label: 'Nombre de la variable', type: 'text' },
      { key: 'value', label: 'Valor', type: 'text' },
    ],
  },
  {
    type: 'HTTP_REQUEST',
    label: 'Consulta API',
    description:
      'Realiza una petición HTTP y guarda la respuesta en variables.',
    fields: [
      {
        key: 'method',
        label: 'Método',
        type: 'select',
        options: [
          { value: 'GET', label: 'GET' },
          { value: 'POST', label: 'POST' },
          { value: 'PUT', label: 'PUT' },
          { value: 'PATCH', label: 'PATCH' },
        ],
      },
      { key: 'url', label: 'URL', type: 'text', placeholder: 'https://…' },
      { key: 'body', label: 'Cuerpo (JSON)', type: 'textarea' },
    ],
  },
  {
    type: 'AI',
    label: 'Asistente IA',
    description:
      'Usa IA para clasificar intención, extraer datos o generar una respuesta.',
    fields: [
      {
        key: 'mode',
        label: 'Acción',
        type: 'select',
        options: [
          { value: 'classify_intent', label: 'Clasificar intención' },
          { value: 'extract_fields', label: 'Extraer información' },
          { value: 'generate_reply', label: 'Generar respuesta' },
        ],
      },
      { key: 'prompt', label: 'Instrucciones', type: 'textarea' },
    ],
  },
  {
    type: 'ADD_LABEL',
    label: 'Agregar Etiqueta',
    description: 'Agrega una etiqueta a la conversación.',
    fields: [{ key: 'label', label: 'Etiqueta', type: 'label' }],
  },
  {
    type: 'REMOVE_LABEL',
    label: 'Quitar Etiqueta',
    description: 'Quita una etiqueta de la conversación.',
    fields: [{ key: 'label', label: 'Etiqueta', type: 'label' }],
  },
  {
    type: 'ASSIGN_TEAM',
    label: 'Asignar Equipo',
    description: 'Asigna la conversación a un equipo.',
    fields: [{ key: 'team', label: 'Equipo', type: 'team' }],
  },
  {
    type: 'ASSIGN_AGENT',
    label: 'Asignar Agente',
    description: 'Asigna la conversación a un agente.',
    fields: [{ key: 'agent', label: 'Agente', type: 'agent' }],
  },
  {
    type: 'UPDATE_CONTACT',
    label: 'Actualizar Contacto',
    description: 'Actualiza un campo del contacto.',
    fields: [
      { key: 'attribute', label: 'Campo', type: 'text' },
      { key: 'value', label: 'Valor', type: 'text' },
    ],
  },
  {
    type: 'CHANGE_CONVERSATION_STATUS',
    label: 'Cambiar Estado',
    description: 'Cambia el estado de la conversación.',
    fields: [
      {
        key: 'status',
        label: 'Nuevo estado',
        type: 'select',
        options: [
          { value: 'open', label: 'Abierta' },
          { value: 'resolved', label: 'Resuelta' },
          { value: 'pending', label: 'Pendiente' },
          { value: 'snoozed', label: 'Pospuesta' },
        ],
      },
    ],
  },
  {
    type: 'HUMAN_HANDOFF',
    label: 'Transferir a Agente',
    description:
      'Detiene la automatización y entrega la conversación a un humano.',
    fields: [
      { key: 'team', label: 'Equipo (opcional)', type: 'team' },
      { key: 'agent', label: 'Agente (opcional)', type: 'agent' },
      { key: 'label', label: 'Etiqueta (opcional)', type: 'label' },
      { key: 'reason', label: 'Motivo de la transferencia', type: 'textarea' },
    ],
  },
  {
    type: 'DELAY',
    label: 'Esperar',
    description: 'Pausa el flujo por un tiempo determinado.',
    fields: [{ key: 'seconds', label: 'Segundos de espera', type: 'number' }],
  },
  {
    type: 'END',
    label: 'Fin del Flujo',
    description: 'Finaliza la ejecución del flujo.',
    fields: [],
  },
];

export const getNodeDefinition = type =>
  NODE_TYPE_DEFINITIONS.find(definition => definition.type === type);

export const getNodeLabel = type => getNodeDefinition(type)?.label || type;
