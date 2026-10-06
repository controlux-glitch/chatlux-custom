# Interface every AI provider must implement (see
# docs/flow-builder-architecture.md section 8). AiNodeHandler only ever
# calls through this interface — it never lets the AI execute SQL/HTTP/
# arbitrary code directly; any follow-up action goes through its own
# authorized node handler.
class FlowEngine::AiProvider::Base
  def classify_intent(_text, options: [])
    raise NotImplementedError
  end

  def extract_fields(_text, schema: {})
    raise NotImplementedError
  end

  def generate_reply(_prompt, context: {})
    raise NotImplementedError
  end
end
