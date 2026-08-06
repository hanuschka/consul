class WhatsappApi::Response
  extend Forwardable

  EMBEDDED_JSON_PATTERN = /\{.*\}/m.freeze

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

  # Meta's own error object, whether the gateway returned it verbatim or buried
  # it as escaped JSON inside 360dialog's "developer_message" string. Its
  # error_user_title / error_user_msg fields are the wording Meta writes for end
  # users; everything else here is diagnostic.
  def error_details
    meta_error = parsed_response.to_h["error"].presence || embedded_meta_error

    return {} if meta_error.blank?

    {
      code: meta_error["code"],
      subcode: meta_error["error_subcode"],
      message: meta_error["message"].to_s,
      user_title: meta_error["error_user_title"].to_s,
      user_message: meta_error["error_user_msg"].to_s
    }
  end

  def developer_message
    parsed_response.to_h.dig("meta", "developer_message").to_s
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

  private

    def embedded_meta_error
      embedded_json = developer_message[EMBEDDED_JSON_PATTERN]

      return if embedded_json.blank?

      JSON.parse(embedded_json)["error"]
    rescue JSON::ParserError
      nil
    end
end
