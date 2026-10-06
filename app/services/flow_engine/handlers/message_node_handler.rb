class FlowEngine::Handlers::MessageNodeHandler < FlowEngine::NodeHandler
  def execute(context, node)
    Messages::MessageBuilder.new(nil, context.conversation, { content: node['params']['content'].to_s }).perform
    FlowEngine::NodeResult.new(status: :continue)
  end
end
