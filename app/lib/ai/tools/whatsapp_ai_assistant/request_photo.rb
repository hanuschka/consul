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
              "always optional. This sends the message itself."

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

    ::Whatsapp::Send.text(account: account, body: with_rights_notice(body.strip))

    halt("Asked for a photo, with the picture-rights notice appended.")
  end

  private

    # The ask is the assistant's and already in the citizen's language; the notice is
    # the locale copy's and has to be brought to the same one, or a Turkish request
    # for a photo carries a German declaration about who owns it.
    def with_rights_notice(body)
      notice = ::Whatsapp::AiAssistant::BotCopyService.line(
        account: account, body: I18n.t("whatsapp.bot.proposal.image_rights_notice")
      )

      [body, notice].join("\n\n")
    end

    def not_collected_error
      { error: "This phase does not take pictures, so there is nothing to ask for. Tell the " \
               "citizen the contribution goes in without one." }
    end

    def blank_body_error
      { error: "The request needs a sentence of your own saying what the photo is for." }
    end
end
