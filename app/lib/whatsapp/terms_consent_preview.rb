module Whatsapp::TermsConsentPreview
  # What the citizen accepts, put in front of them before they answer for it:
  # the terms and the privacy policy, each with its address. Composed here rather
  # than left to the model, because the acceptance is the web form's checkbox —
  # a legal declaration — and a model handed the two addresses could store
  # consent on a reply that had shown neither of them.
  #
  # The button's own words come from here too. Its id is withheld from the
  # assistant (Whatsapp::FlowActions::PLATFORM_WORDED_ACTIONS), so the pill exists
  # only under this block, and RecordTermsConsent can read the offer as proof the
  # citizen saw both links.

  SCOPE = "whatsapp.bot".freeze

  STATEMENT_KEY = "terms.statement".freeze

  CONDITIONS_KEY = "terms.conditions".freeze

  PRIVACY_KEY = "terms.privacy".freeze

  ACCEPT_BUTTON_KEY = "buttons.terms_accept".freeze

  module_function

  # The block and the label of the pill under it, from one translation batch: they
  # arrive together, and two calls are two cache states — a statement in the
  # citizen's language under a button still in the portal's reads as a fault.
  def confirmation(conversation:)
    account = conversation.whatsapp_account
    labels = ::Whatsapp::MessageBlock.labels(
      account: account,
      scope: SCOPE,
      keys: [STATEMENT_KEY, CONDITIONS_KEY, PRIVACY_KEY, ACCEPT_BUTTON_KEY]
    )

    { block: statement_block(labels, account), accept_title: accept_title(labels) }
  end

  # The block is nothing without both addresses, so a missing one leaves it blank
  # and the tool refuses rather than asking for consent to half of it.
  def statement_block(labels, account)
    sections = [labels[STATEMENT_KEY], link_lines(labels, account)]

    return if sections.any?(&:blank?)

    ::Whatsapp::MessageBlock.compose(sections)
  end

  # In the language the citizen is chatting in, the same as the block above them.
  def link_lines(labels, account)
    locale = ::Whatsapp.locale_for(account)
    pairs = [
      [labels[CONDITIONS_KEY], ::Whatsapp::PortalLinks.conditions_url(locale: locale)],
      [labels[PRIVACY_KEY], ::Whatsapp::PortalLinks.privacy_url(locale: locale)]
    ]

    return if pairs.flatten.any?(&:blank?)

    ::Whatsapp::MessageBlock.labelled_lines(pairs)
  end

  # Decided after the translation, because what fits is a property of the label as
  # sent rather than as written.
  def accept_title(labels)
    ::Whatsapp::AssistantActions.fitting_label(
      translated: labels[ACCEPT_BUTTON_KEY],
      original: ::Whatsapp.copy("#{SCOPE}.#{ACCEPT_BUTTON_KEY}")
    )
  end

  private_class_method :statement_block, :link_lines, :accept_title
end
