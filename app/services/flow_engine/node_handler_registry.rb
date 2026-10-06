class FlowEngine::NodeHandlerRegistry
  class << self
    def register(node_type, handler_class)
      handlers[node_type.to_s] = handler_class
    end

    def for(node_type)
      handlers.fetch(node_type.to_s) do
        raise "No FlowEngine::NodeHandler registered for node type '#{node_type}'"
      end
    end

    def handlers
      @handlers ||= {}
    end
  end
end
