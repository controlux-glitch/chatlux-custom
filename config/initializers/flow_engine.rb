# Registers every FlowEngine::NodeHandler against its node type. Adding a new
# node type means adding a handler class + one line here — FlowEngine::Runner
# never needs a switch statement (see docs/flow-builder-architecture.md).
Rails.application.config.to_prepare do
  registry = FlowEngine::NodeHandlerRegistry

  registry.register('TRIGGER', FlowEngine::Handlers::TriggerNodeHandler)
  registry.register('MESSAGE', FlowEngine::Handlers::MessageNodeHandler)
  registry.register('QUESTION', FlowEngine::Handlers::QuestionNodeHandler)
  registry.register('WHATSAPP_BUTTONS', FlowEngine::Handlers::WhatsappButtonsNodeHandler)
  registry.register('WHATSAPP_TEMPLATE', FlowEngine::Handlers::WhatsappTemplateNodeHandler)
  registry.register('WHATSAPP_FLOW', FlowEngine::Handlers::WhatsappFlowNodeHandler)
  registry.register('CONDITION', FlowEngine::Handlers::ConditionNodeHandler)
  registry.register('SET_VARIABLE', FlowEngine::Handlers::SetVariableNodeHandler)
  registry.register('HTTP_REQUEST', FlowEngine::Handlers::HttpRequestNodeHandler)
  registry.register('AI', FlowEngine::Handlers::AiNodeHandler)
  registry.register('ADD_LABEL', FlowEngine::Handlers::AddLabelNodeHandler)
  registry.register('REMOVE_LABEL', FlowEngine::Handlers::RemoveLabelNodeHandler)
  registry.register('ASSIGN_TEAM', FlowEngine::Handlers::AssignTeamNodeHandler)
  registry.register('ASSIGN_AGENT', FlowEngine::Handlers::AssignAgentNodeHandler)
  registry.register('UPDATE_CONTACT', FlowEngine::Handlers::UpdateContactNodeHandler)
  registry.register('CHANGE_CONVERSATION_STATUS', FlowEngine::Handlers::ChangeConversationStatusNodeHandler)
  registry.register('HUMAN_HANDOFF', FlowEngine::Handlers::HumanHandoffNodeHandler)
  registry.register('DELAY', FlowEngine::Handlers::DelayNodeHandler)
  registry.register('END', FlowEngine::Handlers::EndNodeHandler)
end
