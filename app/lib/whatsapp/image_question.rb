module Whatsapp::ImageQuestion
  # Every question whose answer can put a picture on the draft, sent with the two
  # notices the citizen has to read before they choose: that they must hold the
  # rights to a photo of their own, and that the alternative is drawn by a
  # machine. Both lines are legal notices rather than the bot's voice, so they are
  # appended here from the locale copy and the answers stand under them as pills
  # nothing else may offer (Whatsapp::FlowActions::PLATFORM_WORDED_ACTIONS).
  #
  # One place for two askers — Ai::Tools::WhatsappAiAssistant::RequestPhoto asking
  # for a photo, and AttachDraftImage asking about one that arrived unasked — so
  # the notices cannot be dropped from either, and so the draft only counts as
  # having shown them once a message carrying them actually went out.

  NOTICE_KEYS = %w[
    whatsapp.bot.proposal.image_rights_notice
    whatsapp.bot.proposal.image_generation_notice
  ].freeze

  module_function

  # The labels are locale copy rather than the model's, for the same reason the
  # notices above them are: the citizen must always be able to decline a picture,
  # and a set of options the model writes fresh each turn is a set it can also write
  # its way out of.
  #
  # The ask may be the assistant's and already in the citizen's language; the
  # notices and the labels are the locale copy's and have to be brought to the same
  # one, or a Turkish request for a photo carries a German declaration about who
  # owns it. One call for the whole message, because a body and the labels under it
  # are one thing the citizen reads.
  def ask(conversation:, body:, answers:)
    account = conversation.whatsapp_account
    written_labels = labels_for(answers)
    ask_line, *translated = ::Whatsapp::AiAssistant::BotCopyService.call(
      account: account,
      lines: [body, *written_notices, *written_labels]
    )
    notices = translated.first(NOTICE_KEYS.size)
    labels = translated.drop(NOTICE_KEYS.size)

    message = ::Whatsapp::Send.buttons(
      account: account,
      body: [ask_line, *notices].join(::Whatsapp::MessageBlock::PARAGRAPH_BREAK),
      buttons: answer_buttons(answers, labels, written_labels)
    )

    if delivered?(message)
      conversation.record_image_notices_shown!
    end

    message
  end

  def written_notices
    NOTICE_KEYS.map { |key| ::Whatsapp.copy(key) }
  end

  def labels_for(answers)
    answers.map { |action| ::Whatsapp.copy("whatsapp.bot.buttons.#{action}") }
  end

  # The fit is decided after the translation, because the length that fits is a
  # property of the label as sent rather than as written: eighteen characters in
  # German is not eighteen in every language it is put into. Where the translation
  # can only arrive shortened, fitting_label falls back to the written copy — the
  # one thing the citizen must be able to read here in full is the option to go on
  # without a picture.
  def answer_buttons(answers, labels, written_labels)
    answers.zip(labels, written_labels).map do |answer|
      action, translated, written = answer

      {
        id: ::Whatsapp::FlowActions.id_for(action: action),
        title: ::Whatsapp::AssistantActions.fitting_label(
          translated: translated, original: written
        )
      }
    end
  end

  # Outside the service window the send answers nil, and a refused one comes back
  # as a failed message: either way the citizen read nothing.
  def delivered?(message)
    message.present? && !::Whatsapp::Send.refused?(message)
  end

  private_class_method :written_notices, :labels_for, :answer_buttons, :delivered?
end
