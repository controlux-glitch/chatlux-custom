class FlowEngine::Handlers::AssignTeamNodeHandler < FlowEngine::NodeHandler
  include FlowEngine::Handlers::AccountLookup

  def execute(context, node)
    team = find_team(context.account, node['params']['team'])
    return FlowEngine::NodeResult.new(status: :error, error: "Equipo no encontrado: #{node['params']['team']}") if team.nil?

    ActionService.new(context.conversation).assign_team([team.id])
    FlowEngine::NodeResult.new(status: :continue)
  end
end
