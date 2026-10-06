class FlowEngine::Handlers::EndNodeHandler < FlowEngine::NodeHandler
  def execute(_context, _node)
    FlowEngine::NodeResult.new(status: :end)
  end
end
