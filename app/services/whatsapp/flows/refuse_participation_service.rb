class Whatsapp::Flows::RefuseParticipationService < Whatsapp::Flows::BaseService
  # The second group are the phase's participation restrictions. They used to be
  # unreachable here — a phase that applies them requires an account, and the
  # bot required one before any of them could be asked. Guest phases changed
  # that: the bot checks the restrictions the web waives, so a guest can now be
  # refused for a reason that needs saying rather than a generic "not right now".
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

    not_logged_in
    missing_user_data
    only_citizens
    only_specific_geozones
    no_registered_address
    only_specific_streets
    only_specific_registered_address_groupings
    only_specific_ages
  ].freeze

  def initialize(conversation:, reason:)
    super(conversation: conversation)
    @reason = reason.to_s
  end

  # The catalog has no menu to return to, so a refusal ends in plain text rather
  # than in an invitation. What the citizen can do instead is in the copy: the
  # verification link where that is the blocker, the help command otherwise.
  def call
    @conversation.reset_flow!

    Whatsapp::Outbound.text(account: account, body: message)
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
