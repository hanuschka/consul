class Whatsapp::Steps::RefuseParticipationService < ApplicationService
  REASONS_WITH_OWN_COPY = %w[
    phase_missing
    phase_not_supported
    budget_heading_missing
    creation_disabled
    ai_flow_disabled
    phase_not_active
    phase_expired
    phase_not_current
    not_verified
    no_open_phase
    submissions_limit_exceeded
  ].freeze

  def initialize(conversation:, reason:)
    @conversation = conversation
    @reason = reason.to_s
  end

  def call
    @conversation.reset_flow!

    Whatsapp::Outbound.recovery(conversation: @conversation, body: message, actions: [:menu])
  end

  # Also read by the assistant, which explains a refusal in its own words but
  # must not invent a second account of the same rule.
  def self.reason_key(reason)
    return reason.to_s if REASONS_WITH_OWN_COPY.include?(reason.to_s)

    "generic"
  end

  private

    def message
      [I18n.t("whatsapp.bot.refused.#{reason_key}"), verification_hint].compact.join("\n\n")
    end

    def reason_key
      self.class.reason_key(@reason)
    end

    def verification_hint
      return if @reason != "not_verified"

      I18n.t("whatsapp.bot.verification_link", url: verification_url)
    end

    def verification_url
      Rails.application.routes.url_helpers.verification_url(**UrlOptions.default.to_h)
    end
end
