# Return value of FlowEngine::NodeHandler#execute.
#
# status:
#   :continue  - move to the next node (via next_node_id, or the edge matching source_handle)
#   :wait_input - stop advancing; the flow_run is now waiting for the next incoming message
#   :delay     - stop advancing now; FlowEngine::Runner re-enqueues after delay_seconds
#   :end       - the flow run is finished successfully
#   :error     - the flow run failed on this node
class FlowEngine::NodeResult
  attr_reader :status, :next_node_id, :source_handle, :variables_patch, :delay_seconds, :error

  # rubocop:disable Metrics/ParameterLists -- plain value object, one kwarg per NodeResult field
  def initialize(status:, next_node_id: nil, source_handle: nil, variables_patch: {}, delay_seconds: nil, error: nil)
    # rubocop:enable Metrics/ParameterLists
    @status = status
    @next_node_id = next_node_id
    @source_handle = source_handle
    @variables_patch = variables_patch || {}
    @delay_seconds = delay_seconds
    @error = error
  end
end
