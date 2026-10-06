# No FlowEngine::AIProvider implementation is wired up yet (planned for
# Etapa 11, see docs/flow-builder-architecture.md section 8) — this stub
# fails the node explicitly instead of silently doing nothing.
class FlowEngine::Handlers::AiNodeHandler < FlowEngine::NodeHandler
  def execute(_context, _node)
    FlowEngine::NodeResult.new(
      status: :error,
      error: 'El nodo AI aún no tiene un proveedor de IA configurado.'
    )
  end
end
