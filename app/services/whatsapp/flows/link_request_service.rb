class Whatsapp::Flows::LinkRequestService < Whatsapp::Flows::BaseService
  # The one place linking is asked for. Never at first contact and never on a
  # returning message — only here, where the citizen has already chosen
  # something an account is needed for, and that something can be named
  # (CON-2971).
  #
  # Two messages rather than one, and the split is forced rather than chosen:
  # Whatsapp::Send.cta_url carries a single button, so the login link cannot
  # also offer a way back. Asking first costs a tap from the citizen who does
  # want to link and costs nothing at all from the one who does not — and it is
  # the one who does not that the old bare login link left with nowhere to go.
  # The link itself follows from the "yes" pill, through SendLoginLinkService.
  #
  # The consent line rides along because first contact no longer captures it
  # with a tap: this is the moment the number is about to be tied to an
  # account, which is what the consent is about.
  REASONS = %w[
    contributions
    notifications
    participation
    support
    comment
  ].freeze

  # Two entry points because the reason comes from two different places. A pill
  # names the thing the citizen tapped, in the bot's own words; a refused phase
  # has already produced its own permission sentence, which must not be
  # paraphrased into one of the five above — it is the phase's statement of its
  # own rule.
  def self.for_action(conversation:, reason:)
    new(conversation: conversation, intro: reason_phrase(reason)).call
  end

  def self.for_refusal(conversation:, refusal:)
    new(conversation: conversation, intro: refusal).call
  end

  def self.reason_phrase(reason)
    key = REASONS.include?(reason.to_s) ? reason.to_s : "participation"

    Whatsapp.phrase("whatsapp.bot.link_request.#{key}")
  end
  private_class_method :reason_phrase

  def initialize(conversation:, intro:)
    super(conversation: conversation)
    @intro = intro
  end

  def call
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_LINK_DECISION)

    Whatsapp::Send.buttons(
      account: account,
      body: body,
      buttons: Whatsapp::FlowActions.link_request_buttons
    )
  end

  private

    # The reason first, the consent under it. The reason is what the citizen
    # asked for a moment ago and the only part they need to recognise; putting
    # the legal sentence above it would bury the answer to their own question.
    def body
      [@intro, consent].compact_blank.join("\n\n")
    end

    def consent
      I18n.t("whatsapp.bot.onboarding.consent", privacy_url: Whatsapp::PortalLinks.privacy_url)
    end
end
