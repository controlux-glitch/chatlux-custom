# MVP stub: passes a template name through to Messages::MessageBuilder's
# `template_params`, reusing Whatsapp::TemplateProcessorService end to end.
# Full parameter mapping (header/body/button components) is Etapa 7 work
# (see docs/flow-builder-architecture.md section 5) — the editor today only
# collects a template name.
class FlowEngine::Handlers::WhatsappTemplateNodeHandler < FlowEngine::NodeHandler
  def execute(context, node)
    template_name = node['params']['template_name'].to_s
    return FlowEngine::NodeResult.new(status: :error, error: 'WHATSAPP_TEMPLATE requiere el nombre de una plantilla') if template_name.blank?

    Messages::MessageBuilder.new(nil, context.conversation, {
                                   content: node['params']['content'].to_s,
                                   template_params: { name: template_name }
                                 }).perform

    FlowEngine::NodeResult.new(status: :continue)
  end
end
