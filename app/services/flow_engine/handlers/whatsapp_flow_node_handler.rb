# Explicit stub: WhatsApp Flows (Meta's own product) is a distinct concept
# from the Chatwoot Flow Builder and is intentionally not implemented yet
# (see docs/flow-builder-architecture.md section 5).
class FlowEngine::Handlers::WhatsappFlowNodeHandler < FlowEngine::NodeHandler
  def execute(_context, _node)
    FlowEngine::NodeResult.new(status: :error, error: 'El nodo WHATSAPP_FLOW (WhatsApp Flows de Meta) aún no está implementado.')
  end
end
