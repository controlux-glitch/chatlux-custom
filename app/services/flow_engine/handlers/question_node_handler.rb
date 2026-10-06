# First pass (no resume_message): sends the question and pauses the run.
# Second pass (resume_message present, contact just replied): stores the
# reply in `params['variable']` and continues.
class FlowEngine::Handlers::QuestionNodeHandler < FlowEngine::NodeHandler
  def execute(context, node)
    if context.resume_message.present?
      variable = node['params']['variable'].to_s
      patch = variable.present? ? { variable => context.resume_message.content.to_s } : {}
      return FlowEngine::NodeResult.new(status: :continue, variables_patch: patch)
    end

    Messages::MessageBuilder.new(nil, context.conversation, { content: node['params']['content'].to_s }).perform
    FlowEngine::NodeResult.new(status: :wait_input)
  end
end
