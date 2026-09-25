class WhatsappApi::Response
  extend Forwardable

  EMBEDDED_JSON_PATTERN = /\{.*\}/m.freeze

  # Meta subcodes whose own wording is too vague to act on, mapped to copy that
  # names the offending rule. Everything else falls through to Meta's
  # error_user_msg, which is already written for a human reader.
  KNOWN_SUBCODE_MESSAGE_KEYS = {
    2388299 => "adm.whatsapp.api_errors.placeholder_position"
  }.freeze

  MAX_FALLBACK_MESSAGE_LENGTH = 300

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

  # The one line an admin is shown when a call fails, in decreasing order of
  # usefulness: our own copy for a subcode we recognise, Meta's own end-user
  # wording, then whatever diagnostic text is left.
  def admin_error_message
    details = error_details

    known_subcode_message(details) || meta_error_message(details) || fallback_error_message(details)
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

    def known_subcode_message(details)
      key = KNOWN_SUBCODE_MESSAGE_KEYS[details[:subcode].to_i]

      return if key.blank?

      I18n.t(key)
    end

    def meta_error_message(details)
      [details[:user_title], details[:user_message]].reject(&:blank?).join(" — ").presence
    end

    def fallback_error_message(details)
      details[:message].presence ||
        developer_message.presence&.truncate(MAX_FALLBACK_MESSAGE_LENGTH) ||
        error_payload.to_s.truncate(MAX_FALLBACK_MESSAGE_LENGTH)
    end

    def embedded_meta_error
      embedded_json = developer_message[EMBEDDED_JSON_PATTERN]

      return if embedded_json.blank?

      JSON.parse(embedded_json)["error"]
    rescue JSON::ParserError
      nil
    end
end
