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
    organization
    only_citizens
    only_specific_geozones
    no_registered_address
    only_specific_streets
    only_specific_registered_address_groupings
    only_specific_ages
    only_specific_individual_group_values
  ].freeze

  def initialize(conversation:, reason:)
    super(conversation: conversation)
    @reason = reason.to_s
  end

  # The catalog has no menu to return to, so a refusal ends in plain text rather
  # than in an invitation. What the citizen can do instead is in the copy: the
  # verification link where that is the blocker, the help command otherwise.
  #
  # One reason has an actual way out rather than an explanation, and it is the
  # login link — sent with the refusal above it, so the citizen reads why and
  # what to do in one message.
  #
  # The body is built before the reset, and the reset before the delegation.
  # Both orders matter: the reset clears the phase one refusal names, and
  # SendLoginLinkService sets a step the reset would otherwise wipe.
  def call
    body = message
    @conversation.reset_flow!

    return send_login_link(body) if login_required?

    Whatsapp::Send.text(account: account, body: body)
  end

  # A reason the phase raises under its own name, answered with copy written for
  # another. The phase separates "a guest phase with nobody logged in" from
  # "nobody logged in"; to a citizen both are the same sentence, so it is aliased
  # rather than given a second identical line in every locale file.
  COPY_ALIASES = { "guest_not_logged_in" => "not_logged_in" }.freeze

  # Also read by the assistant, which explains a refusal in its own words but
  # must not invent a second account of the same rule.
  def self.reason_key(reason)
    key = COPY_ALIASES.fetch(reason.to_s, reason.to_s)

    return key if REASONS_WITH_OWN_COPY.include?(key)

    "generic"
  end

  # The refusal sentence on its own, without the verification link the flow
  # appends under it. Shared with the assistant's eligibility tool rather than
  # let it build the same lookup: one reason's copy names the groups it is
  # restricted to, and a bare `I18n.t` of that key raises.
  def self.copy_for(reason:, projekt_phase: nil)
    key = reason_key(reason)

    Whatsapp.phrase("whatsapp.bot.refused.#{key}", **interpolations_for(key, projekt_phase))
  end

  # The rule, and under it the way out where there is one. Shared with the
  # support path, which is refused by the same rules but must not go through
  # `call`: that resets the flow, and a citizen refused a support was doing
  # something else at the time — often with a submission of their own open.
  def self.explanation_for(reason:, projekt_phase: nil)
    [
      copy_for(reason: reason, projekt_phase: projekt_phase),
      verification_hint_for(reason)
    ].compact_blank.join("\n\n")
  end

  # Only where verification is genuinely the blocker. Appended to every
  # refusal it sends a citizen who lives outside the eligible area, or whose
  # phase has closed, to a page that cannot unblock them.
  def self.verification_hint_for(reason)
    return if reason_key(reason) != "not_verified"

    Whatsapp.phrase("whatsapp.bot.verification_link", url: verification_url)
  end

  def self.verification_url
    Rails.application.routes.url_helpers.verification_url(**UrlOptions.default.to_h)
  end

  private_class_method :verification_url

  # Only one refusal names anything, and the phase already formats the groups
  # for the web form. Answered per reason rather than at each `I18n.t` so a
  # second interpolated reason is one more branch in one place, and so the
  # groups are only read when they are what is being said.
  def self.interpolations_for(key, projekt_phase)
    return {} if key != "only_specific_individual_group_values"

    { individual_group_values: projekt_phase&.individual_group_value_restriction_formatted.to_s }
  end

  private_class_method :interpolations_for

  private

    # Read off the mapped key rather than the raw reason, so the phase reason
    # aliased onto this one is answered the same way. The bot only ever reaches
    # `not_logged_in` itself: ResourceCreationValidationService answers it for a
    # blank author before the phase is consulted, and a guest phase always has a
    # guest author to offer.
    def login_required?
      self.class.reason_key(@reason) == "not_logged_in"
    end

    def send_login_link(body)
      Whatsapp::Flows::SendLoginLinkService.call(conversation: @conversation, intro: body)
    end

    # The rule, then the way out of it. The refusal keeps its own exact wording —
    # it is a permission statement and the one line here that must not vary —
    # and only the sentence under it is written for this citizen's situation.
    #
    # Skipped where the message already ends in something to act on: the
    # verification hint carries a link, and a refusal that sends the login link
    # is followed by the link itself, so a third suggestion under either is one
    # instruction too many.
    def message
      [refusal_copy, verification_hint, next_step].compact.join("\n\n")
    end

    def next_step
      return if verification_hint.present?
      return if login_required?

      Whatsapp::AiAssistant::RefusalNextStepService.call(
        reason: @reason,
        projekt_phase: @conversation.projekt_phase,
        user: @conversation.user
      )
    end

    def refusal_copy
      self.class.copy_for(reason: @reason, projekt_phase: @conversation.projekt_phase)
    end

    def verification_hint
      self.class.verification_hint_for(@reason)
    end
end
