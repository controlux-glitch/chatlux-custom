# Stops the automation and hands the conversation back to Chatwoot's
# native flow: Conversation#bot_handoff! (same one AgentBot handoffs use)
# plus the same team/agent/label actions as any other automation.
class FlowEngine::Handlers::HumanHandoffNodeHandler < FlowEngine::NodeHandler
  include FlowEngine::Handlers::AccountLookup

  def execute(context, node)
    params = node['params']
    action_service = ActionService.new(context.conversation)

    assign_team_if_present(action_service, context.account, params['team'])
    assign_agent_if_present(action_service, context.account, params['agent'])
    action_service.add_label([params['label']]) if params['label'].present?

    context.conversation.bot_handoff!

    FlowEngine::NodeResult.new(status: :end)
  end

  private

  def assign_team_if_present(action_service, account, identifier)
    return if identifier.blank?

    team = find_team(account, identifier)
    action_service.assign_team([team.id]) if team
  end

  def assign_agent_if_present(action_service, account, identifier)
    return if identifier.blank?

    agent = find_agent(account, identifier)
    action_service.assign_agent([agent.id]) if agent
  end
end
