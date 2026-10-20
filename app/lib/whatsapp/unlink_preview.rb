module Whatsapp::UnlinkPreview
  # What severing the link does, composed here rather than left to the model, for the
  # same reason a draft and a comment are: the sentence makes a promise about what
  # happens to the citizen's data, and a promise sampled from a model is a promise
  # that is sometimes wrong. Asked to word it, the assistant said on one occasion
  # that unlinking deletes account data and contributions permanently and on another
  # that it leaves published contributions alone — on the same commit, minutes apart.
  #
  # Whatsapp::Account#unlink! clears five columns on the account row and touches
  # nothing else, so the portal account and every published contribution survive it.
  # A citizen exercising an erasure right has to be told that, and told where a real
  # erasure is asked for instead.
  #
  # The button's own words come from here too. It is the one pill the assistant may
  # not offer at all (Whatsapp::FlowActions::PLATFORM_WORDED_ACTIONS), because what
  # has to be fixed is not the label alone but the sentence standing above it.

  SCOPE = "whatsapp.bot".freeze

  CONSEQUENCE_KEY = "unlink.consequence".freeze

  ERASURE_KEY = "unlink.erasure".freeze

  CONFIRM_BUTTON_KEY = "buttons.unlink_confirm".freeze

  module_function

  # The block and the label of the pill under it, from one translation batch: they
  # arrive in the same message, and two calls are two cache states — a question in
  # the citizen's language under a button still in the portal's reads as a fault.
  def confirmation(conversation:)
    labels = ::Whatsapp::MessageBlock.labels(
      account: conversation.whatsapp_account,
      scope: SCOPE,
      keys: [CONSEQUENCE_KEY, ERASURE_KEY, CONFIRM_BUTTON_KEY]
    )

    { block: statement_block(labels), confirm_title: confirm_title(labels) }
  end

  def statement_block(labels)
    ::Whatsapp::MessageBlock.compose([labels[CONSEQUENCE_KEY], erasure_line(labels)])
  end

  # The address underneath the sentence rather than inside it, the rule every closing
  # line in these blocks follows: a long sentence must not be able to push the link
  # into the middle of a wrapped line.
  def erasure_line(labels)
    [labels[ERASURE_KEY], ::Whatsapp::PortalLinks.delete_account_url]
      .compact_blank
      .join(::Whatsapp::MessageBlock::LINE_BREAK)
      .presence
  end

  # Decided after the translation, because what fits is a property of the label as
  # sent: a German compound that fits the twenty characters is not the same length
  # once it has been put into another language, and a title WhatsApp refuses is a
  # message it refuses whole.
  def confirm_title(labels)
    ::Whatsapp::AssistantActions.fitting_label(
      translated: labels[CONFIRM_BUTTON_KEY],
      original: ::Whatsapp.copy("#{SCOPE}.#{CONFIRM_BUTTON_KEY}")
    )
  end

  private_class_method :statement_block, :erasure_line, :confirm_title
end
