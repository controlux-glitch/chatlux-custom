# SSRF protection is inherited from SafeFetch (blocks private/internal
# networks by default; see lib/safe_fetch.rb) rather than reimplemented
# here, per docs/flow-builder-architecture.md section 7.
class FlowEngine::Handlers::HttpRequestNodeHandler < FlowEngine::NodeHandler
  ALLOWED_METHODS = %w[GET POST PUT PATCH].freeze
  MAX_RESPONSE_BYTES = 1.megabyte

  def execute(_context, node)
    method = node['params']['method'].to_s.upcase
    return error("Método HTTP no soportado: #{method}") unless ALLOWED_METHODS.include?(method)

    url = node['params']['url'].to_s
    return error('HTTP_REQUEST requiere una URL') if url.blank?

    raw_response = fetch(method, url, node['params']['body'])
    FlowEngine::NodeResult.new(status: :continue, variables_patch: { 'api' => safe_parse_json(raw_response) })
  rescue SafeFetch::Error => e
    error(e.message)
  end

  private

  def fetch(method, url, body)
    raw_response = nil
    SafeFetch.fetch(
      url,
      method: method.downcase.to_sym,
      body: body.presence,
      headers: { 'Content-Type' => 'application/json' },
      validate_content_type: false,
      max_bytes: MAX_RESPONSE_BYTES
    ) { |result| raw_response = File.read(result.tempfile) }
    raw_response
  end

  def safe_parse_json(raw_response)
    JSON.parse(raw_response.to_s)
  rescue JSON::ParserError
    {}
  end

  def error(message)
    FlowEngine::NodeResult.new(status: :error, error: message)
  end
end
