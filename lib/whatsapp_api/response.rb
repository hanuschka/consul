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

  # Untruncated transport-level facts for admin diagnostics. Never includes the
  # request headers, so the API key cannot leak into a view.
  def technical_details
    {
      I18n.t("adm.whatsapp.test_message.details.status") => "#{code} #{message}".strip,
      I18n.t("adm.whatsapp.test_message.details.url") => request&.last_uri.to_s,
      I18n.t("adm.whatsapp.test_message.details.response") => body.to_s
    }
  end
end
