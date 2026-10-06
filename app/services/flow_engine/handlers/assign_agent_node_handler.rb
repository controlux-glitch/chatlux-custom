class FlowEngine::Handlers::AssignAgentNodeHandler < FlowEngine::NodeHandler
  include FlowEngine::Handlers::AccountLookup

  def execute(context, node)
    agent = find_agent(context.account, node['params']['agent'])
    return FlowEngine::NodeResult.new(status: :error, error: "Agente no encontrado: #{node['params']['agent']}") if agent.nil?

    ActionService.new(context.conversation).assign_agent([agent.id])
    FlowEngine::NodeResult.new(status: :continue)
  end
end
