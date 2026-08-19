module Whatsapp::ParticipationRules
  # Why a phase refused this citizen, stated as the rule rather than as the
  # sentence they read. The sentence is the assistant's — written for the question
  # they actually asked, in their language, in the address form the portal chose —
  # so what this owes it is the fact underneath: what the phase requires, and what
  # the citizen could do about it.
  #
  # English on purpose, and in code rather than in a locale file. These strings are
  # read by a model and never by a person, which is also true of every tool
  # description beside them; putting them through I18n would make them look
  # translatable and invite a translation nobody reads.
  #
  # The keys are ProjektPhase#permission_problem's own symbols, which is what makes
  # this reusable: the same verdict that refuses a submission on the web refuses one
  # here, and a reason added there arrives here as :generic rather than as a wrong
  # explanation.
  RULES = {
    phase_missing: "The participation phase no longer exists or has been removed.",
    phase_not_supported: "This kind of phase cannot be contributed to from WhatsApp.",
    budget_heading_missing: "The budget behind this phase is not fully set up yet.",
    creation_disabled: "This phase does not accept new contributions.",
    ai_flow_disabled: "This phase does not accept contributions written with assistance.",
    phase_not_active: "This phase is not running.",
    phase_expired: "This phase has already ended.",
    phase_not_current: "This phase is not the one currently running in its projekt.",
    not_verified: "The citizen's account has to be verified first.",
    no_open_phase: "Nothing is open for contributions in this projekt right now.",
    submissions_limit_exceeded:
      "The citizen has already submitted as many contributions as this phase allows.",
    not_logged_in: "This phase requires a linked account; guests cannot contribute to it.",
    guest_not_logged_in: "This phase requires a linked account; guests cannot contribute to it.",
    missing_user_data: "The citizen's account is missing details this phase requires.",
    organization: "Organisation accounts cannot contribute to this phase.",
    only_citizens: "Only verified residents may contribute to this phase.",
    only_specific_geozones: "This phase is limited to citizens living in particular districts.",
    no_registered_address:
      "This phase needs a registered address on the account, and there is none.",
    only_specific_streets: "This phase is limited to citizens living in particular streets.",
    only_specific_registered_address_groupings:
      "This phase is limited to citizens in particular registered address groups.",
    only_specific_ages: "This phase is limited to citizens in a particular age range.",
    only_specific_individual_group_values:
      "This phase is limited to citizens in particular groups."
  }.freeze

  GENERIC_RULE = "This phase does not allow this citizen to contribute right now.".freeze

  module_function

  # The rule, plus whatever would resolve it. Verification is the one refusal a
  # citizen can act on themselves, so its link travels with it — the model has
  # nothing else to offer them, and a refusal with no way forward is where the
  # scripted flow used to leave people.
  def explain(reason:, projekt_phase: nil)
    [rule_for(reason), detail_for(reason, projekt_phase), remedy_for(reason)]
      .compact_blank
      .join(" ")
  end

  def rule_for(reason)
    RULES.fetch(reason.to_s.to_sym, GENERIC_RULE)
  end

  # The one rule whose statement is meaningless without the values behind it: which
  # groups a phase is limited to is a per-phase list, and "particular groups" tells
  # the citizen nothing they can check themselves against.
  def detail_for(reason, projekt_phase)
    return if reason.to_s != "only_specific_individual_group_values"

    values = projekt_phase&.individual_group_value_restriction_formatted.to_s

    return if values.blank?

    "The groups it allows: #{values}."
  end

  def remedy_for(reason)
    return verification_remedy if reason.to_s == "not_verified"
    return account_remedy if %w[not_logged_in guest_not_logged_in].include?(reason.to_s)

    nil
  end

  def verification_remedy
    "Send them the verification page with send_link: #{verification_url}"
  end

  def account_remedy
    "Offer to link their account and call send_login_link when they agree."
  end

  def verification_url
    Rails.application.routes.url_helpers.verification_url(**::UrlOptions.default.to_h)
  end
end
