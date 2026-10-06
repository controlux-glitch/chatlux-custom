class FlowEngine::Handlers::UpdateContactNodeHandler < FlowEngine::NodeHandler
  STANDARD_ATTRIBUTES = %w[name email phone_number].freeze

  def execute(context, node)
    attribute = node['params']['attribute'].to_s
    return FlowEngine::NodeResult.new(status: :error, error: 'UPDATE_CONTACT requiere un campo') if attribute.blank?

    value = node['params']['value']
    if STANDARD_ATTRIBUTES.include?(attribute)
      context.contact.update!(attribute => value)
    else
      context.contact.update!(custom_attributes: context.contact.custom_attributes.merge(attribute => value))
    end

    FlowEngine::NodeResult.new(status: :continue)
  end
end
