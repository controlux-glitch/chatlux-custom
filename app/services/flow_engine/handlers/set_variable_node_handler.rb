class FlowEngine::Handlers::SetVariableNodeHandler < FlowEngine::NodeHandler
  def execute(_context, node)
    variable = node['params']['variable'].to_s
    return FlowEngine::NodeResult.new(status: :error, error: 'SET_VARIABLE requiere un nombre de variable') if variable.blank?

    FlowEngine::NodeResult.new(status: :continue, variables_patch: { variable => node['params']['value'] })
  end
end
