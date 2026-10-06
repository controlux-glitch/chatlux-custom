# Sends a WhatsApp Cloud API interactive message (reply buttons if <= 3
# items, list otherwise) by reusing Message#content_type == 'input_select',
# the same primitive already used to send interactive replies today
# (see Whatsapp::Providers::BaseService#create_payload_based_on_items).
#
# On resume, branches by the button's stable id (content_attributes
# submitted_values.id) when available, falling back to matching the
# reply's text against the configured button titles.
class FlowEngine::Handlers::WhatsappButtonsNodeHandler < FlowEngine::NodeHandler
  def execute(context, node)
    if context.resume_message.present?
      selected_id = extract_selected_button_id(node, context.resume_message)
      return FlowEngine::NodeResult.new(status: :continue, source_handle: selected_id)
    end

    items = Array(node['params']['buttons']).map { |button| { title: button['title'], value: button['id'] } }
    Messages::MessageBuilder.new(nil, context.conversation, {
                                   content: node['params']['content'].to_s,
                                   content_type: 'input_select',
                                   content_attributes: { items: items }
                                 }).perform

    FlowEngine::NodeResult.new(status: :wait_input)
  end

  private

  def extract_selected_button_id(node, message)
    submitted_id = message.content_attributes&.dig('submitted_values', 'id')
    return submitted_id if submitted_id.present?

    buttons = Array(node['params']['buttons'])
    matched = buttons.find { |button| button['title'].to_s.strip.casecmp?(message.content.to_s.strip) }
    matched ? matched['id'] : message.content.to_s
  end
end
