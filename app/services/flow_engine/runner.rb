# Advances a single FlowRun through its definition_snapshot, one node at a
# time, persisting state after every step (never keeping run state only in
# memory). Independent of the visual editor: it only reads the frozen
# {nodes:, edges:} snapshot captured when the flow was published.
class FlowEngine::Runner
  MAX_STEPS_PER_ADVANCE = 25

  def initialize(flow_run)
    @flow_run = flow_run
    definition = flow_run.definition_snapshot || {}
    @nodes = (definition['nodes'] || []).index_by { |node| node['id'] }
    @edges = definition['edges'] || []
    @context = FlowEngine::Context.new(flow_run)
  end

  def advance(resume_message: nil)
    return if finished?

    current_id = @flow_run.current_node_id || start_node_id
    return finish!(:completed) if current_id.nil?

    steps = 0

    loop do
      steps += 1
      next_id = perform_step(current_id, steps, resume_message)
      return if next_id == :stop
      return finish!(:completed) if next_id.nil?

      current_id = next_id
      @flow_run.update!(current_node_id: current_id, status: :running)
    end
  end

  private

  def finished?
    !@flow_run.active?
  end

  # Runs one node and returns the next node id, nil (chain ends here), or
  # :stop (a terminal/non-continuing outcome already handled advance/finish!).
  def perform_step(current_id, steps, resume_message)
    if steps > MAX_STEPS_PER_ADVANCE
      finish!(:failed, cycle_error_message)
      return :stop
    end

    node = @nodes[current_id]
    if node.nil?
      finish!(:failed, "El nodo #{current_id} no existe en la definición del flujo")
      return :stop
    end

    @context.resume_message = steps == 1 ? resume_message : nil
    advance_past(current_id, execute_node(node))
  end

  def cycle_error_message
    "Se excedieron #{MAX_STEPS_PER_ADVANCE} pasos en un solo avance (posible ciclo)"
  end

  # Applies a node's result and returns either the next node id to run,
  # nil (the chain ends here, run completed), or :stop (the loop already
  # returned control - waiting for input, delayed, ended, or failed).
  def advance_past(current_id, result)
    case result.status
    when :wait_input
      @flow_run.update!(current_node_id: current_id, status: :waiting_input)
      :stop
    when :end
      finish!(:completed)
      :stop
    when :error
      finish!(:failed, result.error)
      :stop
    when :delay
      schedule_delay(current_id, result)
      :stop
    else
      result.next_node_id || next_node_id_for(current_id, result.source_handle)
    end
  end

  def start_node_id
    @nodes.values.find { |node| node['type'] == 'TRIGGER' }&.dig('id')
  end

  def execute_node(node)
    handler = FlowEngine::NodeHandlerRegistry.for(node['type'])
    rendered_node = node.merge('params' => @context.render(node['params'] || {}))
    started_at = Time.current

    result = run_handler(handler, rendered_node)
    persist_variables(result.variables_patch)
    record_event(rendered_node, result, started_at)
    result
  end

  def run_handler(handler, rendered_node)
    Current.executed_by = @flow_run
    handler.new.execute(@context, rendered_node)
  rescue StandardError => e
    Rails.logger.error("[FlowEngine::Runner] #{rendered_node['type']} node #{rendered_node['id']} raised #{e.class}: #{e.message}")
    FlowEngine::NodeResult.new(status: :error, error: e.message)
  ensure
    Current.executed_by = nil
  end

  def persist_variables(patch)
    return if patch.blank?

    @flow_run.update!(variables: @flow_run.variables.merge(patch))
  end

  def record_event(node, result, started_at)
    FlowRunEvent.create!(
      account_id: @flow_run.account_id,
      flow_run: @flow_run,
      node_id: node['id'],
      node_type: node['type'],
      input: node['params'] || {},
      output: { variables_patch: result.variables_patch, source_handle: result.source_handle }.compact,
      status: event_status_for(result.status),
      error_message: result.error,
      next_node_id: result.next_node_id,
      duration_ms: ((Time.current - started_at) * 1000).round
    )
  end

  def event_status_for(status)
    return :error if status == :error
    return :waiting if %i[wait_input delay].include?(status)

    :success
  end

  def next_node_id_for(current_id, source_handle)
    candidates = @edges.select { |edge| edge['source'] == current_id }
    return candidates.first['target'] if candidates.one?

    matching_handle_target(candidates, source_handle) || default_target(candidates)
  end

  def matching_handle_target(candidates, source_handle)
    return nil if source_handle.blank?

    candidates.find { |edge| edge['source_handle'] == source_handle }&.dig('target')
  end

  def default_target(candidates)
    candidates.find { |edge| edge['source_handle'].blank? }&.dig('target')
  end

  def schedule_delay(current_id, result)
    next_id = next_node_id_for(current_id, result.source_handle) || current_id
    @flow_run.update!(current_node_id: next_id, status: :running)
    FlowEngine::AdvanceJob.set(wait: [result.delay_seconds.to_i, 0].max.seconds).perform_later(@flow_run.id)
  end

  def finish!(status, error_message = nil)
    @flow_run.update!(status: status, error_message: error_message, finished_at: Time.current)
  end
end
