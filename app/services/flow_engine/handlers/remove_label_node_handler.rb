class FlowEngine::Handlers::RemoveLabelNodeHandler < FlowEngine::NodeHandler
  def execute(context, node)
    label = node['params']['label'].to_s
    return FlowEngine::NodeResult.new(status: :error, error: 'REMOVE_LABEL requiere una etiqueta') if label.blank?

    ActionService.new(context.conversation).remove_label([label])
    FlowEngine::NodeResult.new(status: :continue)
  end
end
