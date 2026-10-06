json.partial! 'flow_run', formats: [:json], flow_run: @flow_run

json.events do
  json.array! @flow_run.flow_run_events.order(:created_at) do |event|
    json.id event.id
    json.node_id event.node_id
    json.node_type event.node_type
    json.input event.input
    json.output event.output
    json.status event.status
    json.error_message event.error_message
    json.next_node_id event.next_node_id
    json.duration_ms event.duration_ms
    json.created_at event.created_at
  end
end
