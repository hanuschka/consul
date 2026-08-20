class Ai::Tools::WhatsappAiAssistant::RequestPhoto < Ai::Tools::WhatsappAiAssistant::BaseTool
  # Asking for a photo is a sentence, so by every rule here it should not be a tool.
  # It is one for a single reason: what the citizen sends becomes a picture on a
  # public civic page under their name, and they have to be told they must hold its
  # rights *before* they send it. That line is a legal notice rather than the bot's
  # voice, so it is appended here from the locale copy — the model writes the ask and
  # cannot paraphrase the notice away or forget it.
  #
  # The scripted flow made the same guarantee by construction, joining the notice onto
  # every upload prompt so the ask, the re-ask and the failure all carried it. This is
  # that guarantee, kept.
  description "Asks the citizen to send a photo for their draft, in your own words, and appends " \
              "the notice about picture rights that has to accompany the request. Use it whenever " \
              "you ask for a photo — never write the request yourself, because the notice would " \
              "be missing. draft_status says whether this phase takes pictures at all and whether " \
              "the citizen has already declined one; do not ask again if they have. A photo is " \
              "always optional, and the three ways to answer — send one, have one made, go on " \
              "without — arrive as buttons of their own, so do not offer them again in your " \
              "sentence. This sends the message itself."

  params do
    string :body,
      description: "Your request for the photo, in the citizen's language, saying it is optional."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_IMAGE_UPLOAD
  end

  def execute(body:)
    return no_draft_error if draft_resource.blank?
    return not_collected_error if !conversation.image_question_available?
    return blank_body_error if body.to_s.strip.blank?

    ask, notice, *labels = translated_lines(body.strip)

    ::Whatsapp::Send.buttons(
      account: account,
      body: [ask, notice].join("\n\n"),
      buttons: image_answer_buttons(labels)
    )

    halt("Asked for a photo, with the picture-rights notice and the three ways to answer.")
  end

  private

    # The labels are locale copy rather than the model's, for the same reason the
    # notice below them is: the citizen must always be able to decline a picture, and
    # a set of options the model writes fresh each turn is a set it can also write its
    # way out of. Three of them is what a message holds, and the phase either collects
    # pictures or this tool has already refused, so all three always apply.
    #
    # The ask is the assistant's and already in the citizen's language; the notice and
    # the labels are the locale copy's and have to be brought to the same one, or a
    # Turkish request for a photo carries a German declaration about who owns it. One
    # call for the whole message, because a body and the labels under it are one thing
    # the citizen reads.
    #
    def translated_lines(body)
      ::Whatsapp::AiAssistant::BotCopyService.call(
        account: account,
        lines: [body, I18n.t("whatsapp.bot.proposal.image_rights_notice"), *written_labels]
      )
    end

    # The fit is decided after the translation, because the length that fits is a
    # property of the label as sent rather than as written: eighteen characters in
    # German is not eighteen in every language it is put into. Where the translation
    # can only arrive cut mid-word, fitting_label falls back to the written copy —
    # the one thing the citizen must be able to read here in full is the option to
    # go on without a picture.
    def image_answer_buttons(labels)
      ::Whatsapp::FlowActions::IMAGE_ANSWERS.zip(labels, written_labels).map do |answer|
        action, translated, written = answer

        {
          id: ::Whatsapp::FlowActions.id_for(action: action),
          title: ::Whatsapp::AssistantActions.fitting_label(
            translated: translated, original: written
          )
        }
      end
    end

    def written_labels
      @written_labels ||= ::Whatsapp::FlowActions::IMAGE_ANSWERS.map do |action|
        I18n.t("whatsapp.bot.buttons.#{action}")
      end
    end

    def not_collected_error
      { error: "This phase does not take pictures, so there is nothing to ask for. Tell the " \
               "citizen the contribution goes in without one." }
    end

    def blank_body_error
      { error: "The request needs a sentence of your own saying what the photo is for." }
    end
end
