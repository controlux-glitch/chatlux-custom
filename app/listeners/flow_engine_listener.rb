class FlowEngineListener < BaseListener
  def conversation_created(event)
    return if performed_by_flow_engine?(event)

    conversation, account = extract_conversation_and_account(event)
    start_matching_flows(conversation, account, trigger_type: 'new_conversation')
  end

  def message_created(event)
    return if performed_by_flow_engine?(event)

    message, account = extract_message_and_account(event)
    return unless message.incoming?

    conversation = message.conversation
    return if conversation.blank?

    active_run = FlowRun.active.find_by(conversation_id: conversation.id)
    if active_run
      FlowEngine::AdvanceJob.perform_later(active_run.id, resume_message_id: message.id)
      return
    end

    start_matching_flows(conversation, account, trigger_type: 'keyword', message: message)
  end

  private

  # A message/conversation created by the flow engine itself (Current.executed_by
  # set to the FlowRun, see FlowEngine::Runner) must never re-trigger a new run
  # or be mistaken for the contact's reply — same anti-loop convention as
  # AutomationRuleListener#performed_by_automation?.
  def performed_by_flow_engine?(event)
    event.data[:performed_by].present? && event.data[:performed_by].instance_of?(FlowRun)
  end

  def start_matching_flows(conversation, account, trigger_type:, message: nil)
    return if account.blank? || conversation.blank?

    flow_definitions = FlowDefinition.published
                                     .joins(:flow_definition_inboxes)
                                     .where(
                                       account_id: account.id,
                                       flow_definition_inboxes: { inbox_id: conversation.inbox_id, status: :active }
                                     )

    flow_definitions.find_each do |flow_definition|
      next unless trigger_matches?(flow_definition, trigger_type, message)
      break if FlowRun.active.exists?(conversation_id: conversation.id)

      flow_run = create_flow_run(flow_definition, conversation)
      FlowEngine::AdvanceJob.perform_later(flow_run.id)
    rescue ActiveRecord::RecordNotUnique
      break
    end
  end

  def trigger_matches?(flow_definition, trigger_type, message)
    trigger_node = find_trigger_node(flow_definition)
    return false if trigger_node.nil?

    configured_type = trigger_node.dig('params', 'trigger_type')
    return configured_type == 'new_conversation' if trigger_type == 'new_conversation'

    keyword_trigger_matches?(configured_type, trigger_node, message)
  end

  def find_trigger_node(flow_definition)
    ((flow_definition.published_definition || {})['nodes'] || []).find { |node| node['type'] == 'TRIGGER' }
  end

  def keyword_trigger_matches?(configured_type, trigger_node, message)
    return false unless configured_type == 'keyword'

    keyword = trigger_node.dig('params', 'keyword').to_s.strip
    return false if keyword.blank? || message.nil?

    message.content.to_s.downcase.include?(keyword.downcase)
  end

  def create_flow_run(flow_definition, conversation)
    FlowRun.create!(
      account_id: flow_definition.account_id,
      flow_definition: flow_definition,
      flow_version: flow_definition.version,
      conversation: conversation,
      contact: conversation.contact,
      inbox: conversation.inbox,
      status: :running,
      definition_snapshot: flow_definition.published_definition
    )
  end
end
