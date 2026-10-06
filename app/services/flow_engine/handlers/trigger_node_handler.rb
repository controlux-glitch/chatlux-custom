# TRIGGER is the entry point of every flow. Matching against the actual
# event (new conversation / keyword) already happened in FlowEngineListener
# before the FlowRun was created, so this handler is a pure pass-through.
class FlowEngine::Handlers::TriggerNodeHandler < FlowEngine::NodeHandler
  def execute(_context, _node)
    FlowEngine::NodeResult.new(status: :continue)
  end
end
