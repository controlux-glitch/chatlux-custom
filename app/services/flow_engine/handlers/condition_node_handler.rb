class FlowEngine::Handlers::ConditionNodeHandler < FlowEngine::NodeHandler
  OPERATORS = {
    'equals' => ->(a, b) { a == b },
    'not_equals' => ->(a, b) { a != b },
    'contains' => ->(a, b) { a.to_s.include?(b.to_s) },
    'not_contains' => ->(a, b) { a.to_s.exclude?(b.to_s) },
    'greater_than' => ->(a, b) { a.to_f > b.to_f },
    'less_than' => ->(a, b) { a.to_f < b.to_f },
    'exists' => ->(a, _b) { a.present? },
    'not_exists' => ->(a, _b) { a.blank? }
  }.freeze

  def execute(_context, node)
    variable = node['params']['variable'].to_s
    value = node['params']['value'].to_s
    operator = OPERATORS[node['params']['operator']] || OPERATORS['equals']

    matched = operator.call(variable, value)
    FlowEngine::NodeResult.new(status: :continue, source_handle: matched ? 'yes' : 'no')
  end
end
