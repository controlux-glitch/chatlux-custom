# Registry/Handler pattern (see docs/flow-builder-architecture.md section 2):
# one subclass per node type, registered in config/initializers/flow_engine.rb,
# so FlowEngine::Runner never needs a big switch statement.
class FlowEngine::NodeHandler
  # @param context [FlowEngine::Context]
  # @param node [Hash] the node from the flow definition snapshot, with
  #   'params' already Liquid-rendered against contact/conversation/account/variables.
  # @return [FlowEngine::NodeResult]
  def execute(_context, _node)
    raise NotImplementedError, "#{self.class} must implement #execute"
  end
end
