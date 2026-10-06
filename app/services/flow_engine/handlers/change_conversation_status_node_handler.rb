class FlowEngine::Handlers::ChangeConversationStatusNodeHandler < FlowEngine::NodeHandler
  def execute(context, node)
    status = node['params']['status'].to_s
    return FlowEngine::NodeResult.new(status: :error, error: 'CHANGE_CONVERSATION_STATUS requiere un estado') if status.blank?

    ActionService.new(context.conversation).change_status([status])
    FlowEngine::NodeResult.new(status: :continue)
  end
end
