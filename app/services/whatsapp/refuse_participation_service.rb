class Whatsapp::RefuseParticipationService < ApplicationService
  REASONS_WITH_OWN_COPY = %w[
    phase_missing
    phase_not_proposal
    creation_disabled
    ai_flow_disabled
    phase_not_active
    phase_expired
    phase_not_current
    not_verified
    no_open_phase
  ].freeze

  def initialize(conversation:, reason:)
    @conversation = conversation
    @reason = reason.to_s
  end

  def call
    @conversation.reset_flow!

    Whatsapp::SendRecoveryService.call(conversation: @conversation, body: message, actions: [:menu])
  end

  private

    def message
      [I18n.t("whatsapp.bot.refused.#{reason_key}"), verification_hint].compact.join("\n\n")
    end

    def reason_key
      return @reason if REASONS_WITH_OWN_COPY.include?(@reason)

      "generic"
    end

    def verification_hint
      return if @reason != "not_verified"

      I18n.t("whatsapp.bot.verification_link", url: verification_url)
    end

    def verification_url
      Rails.application.routes.url_helpers.verification_url(**UrlOptions.default.to_h)
    end
end
