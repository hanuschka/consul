class Whatsapp::ApiErrorMessageService < ApplicationService
  # Meta subcodes whose own wording is too vague to act on, mapped to copy that
  # names the offending rule. Everything else falls through to Meta's
  # error_user_msg, which is already written for a human reader.
  KNOWN_SUBCODE_KEYS = {
    2388299 => "adm.whatsapp.api_errors.placeholder_position"
  }.freeze

  MAX_FALLBACK_LENGTH = 300

  def initialize(response)
    @response = response
  end

  def call
    return I18n.t("adm.whatsapp.not_configured") if @response.blank?

    known_subcode_message || meta_message || fallback_message
  end

  private

    def details
      @details ||= @response.error_details
    end

    def known_subcode_message
      key = KNOWN_SUBCODE_KEYS[details[:subcode].to_i]

      return if key.blank?

      I18n.t(key)
    end

    def meta_message
      [details[:user_title], details[:user_message]].reject(&:blank?).join(" — ").presence
    end

    def fallback_message
      details[:message].presence ||
        @response.developer_message.presence&.truncate(MAX_FALLBACK_LENGTH) ||
        @response.error_payload.to_s.truncate(MAX_FALLBACK_LENGTH)
    end
end
