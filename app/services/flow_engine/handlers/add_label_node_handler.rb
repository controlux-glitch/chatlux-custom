class FlowEngine::Handlers::AddLabelNodeHandler < FlowEngine::NodeHandler
  def execute(context, node)
    label = node['params']['label'].to_s
    return FlowEngine::NodeResult.new(status: :error, error: 'ADD_LABEL requiere una etiqueta') if label.blank?

    ActionService.new(context.conversation).add_label([label])
    FlowEngine::NodeResult.new(status: :continue)
  end
end
