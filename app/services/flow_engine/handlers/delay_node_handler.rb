# FlowEngine::Runner interprets :delay by re-enqueuing FlowEngine::AdvanceJob
# after delay_seconds instead of blocking (never `sleep` in a worker).
class FlowEngine::Handlers::DelayNodeHandler < FlowEngine::NodeHandler
  def execute(_context, node)
    seconds = node['params']['seconds'].to_i
    FlowEngine::NodeResult.new(status: :delay, delay_seconds: [seconds, 0].max)
  end
end
