# Value object passed to every FlowEngine::NodeHandler#execute call.
# Owns variable interpolation (Liquid, reusing the same Drop classes as
# Message#Liquidable) so handlers never touch Liquid directly.
class FlowEngine::Context
  attr_reader :flow_run, :conversation, :contact, :account, :inbox
  attr_accessor :resume_message

  def initialize(flow_run)
    @flow_run = flow_run
    @conversation = flow_run.conversation
    @contact = flow_run.contact
    @account = flow_run.account
    @inbox = flow_run.inbox
  end

  def variables
    flow_run.variables
  end

  # Recursively interpolates {{contact.name}}-style variables in strings,
  # walking hashes/arrays (same recursion shape as Liquidable#process_liquid_in_hash).
  def render(value)
    case value
    when String
      render_string(value)
    when Hash
      value.transform_values { |v| render(v) }
    when Array
      value.map { |v| render(v) }
    else
      value
    end
  end

  private

  def render_string(value)
    return value if value.blank?

    Liquid::Template.parse(value).render(drops)
  rescue Liquid::Error
    value
  end

  def drops
    {
      'contact' => ContactDrop.new(contact),
      'conversation' => ConversationDrop.new(conversation),
      'account' => AccountDrop.new(account),
      'flow_run' => FlowRunDrop.new(flow_run)
    }.merge(variables.is_a?(Hash) ? variables.stringify_keys : {})
  end
end
