class WhatsappApi::Response
  extend Forwardable

  def_delegators :@response, :code, :headers, :body, :message, :request, :[], :dig

  def initialize(response)
    @response = response
  end

  def success?
    @response&.success? || false
  end

  def parsed_response
    @response&.parsed_response
  end

  def message_id
    parsed_response.to_h.dig("messages", 0, "id")
  end

  def error_payload
    parsed_response.to_h["error"] || parsed_response.to_h["meta"] || { "body" => body.to_s.first(500) }
  end
end
