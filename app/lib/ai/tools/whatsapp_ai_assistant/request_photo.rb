class Ai::Tools::WhatsappAiAssistant::RequestPhoto < Ai::Tools::WhatsappAiAssistant::BaseTool
  # Asking for a photo is a sentence, so by every rule here it should not be a tool.
  # It is one for a single reason: whichever picture is chosen becomes a picture on a
  # public civic page under the citizen's name, and what they have to know about it
  # they have to know *before* they choose — that they must hold the rights to a photo
  # of their own, and that the alternative is drawn by a machine. Both lines are legal
  # notices rather than the bot's voice, so Whatsapp::ImageQuestion appends them from
  # the locale copy: the model writes the ask and cannot paraphrase them away or
  # forget them.
  #
  # The scripted flow made the same guarantee by construction, joining the rights
  # notice onto every upload prompt so the ask, the re-ask and the failure all carried
  # it. This is that guarantee, kept, and extended to the answer the flow did not
  # offer.
  description "Asks the citizen to send a photo for their draft, in your own words, and appends " \
              "the notices about picture rights and generated pictures that have to accompany " \
              "the request. Use it whenever you ask for a photo — never write the request " \
              "yourself, because the notices would be missing. draft_status says whether this " \
              "phase takes pictures at all and whether the citizen has already declined one; do " \
              "not ask again if they have. A photo is always optional, and all three answers — " \
              "send one, have one generated, or go on without — arrive as buttons of their own, " \
              "so do not offer them again in your sentence. A tap on the generate button comes " \
              "back to you as a message, and generate_draft_image is what you answer it with. " \
              "This sends the message itself."

  params do
    string :body,
      description: "Your request for the photo, in the citizen's language, saying it is optional."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_IMAGE_UPLOAD
  end

  def execute(body:)
    refusal = refuse_before_preview

    return refusal if refusal.present?
    return no_draft_error if draft_resource.blank?
    return not_collected_error if !conversation.image_question_available?
    return blank_body_error if body.to_s.strip.blank?

    # Three answers, and the phase either collects pictures or this tool has
    # already refused, so all three always apply.
    ::Whatsapp::ImageQuestion.ask(
      conversation: conversation,
      body: body.strip,
      answers: ::Whatsapp::FlowActions::IMAGE_ANSWERS
    )

    halt("Asked for a photo, with both notices and the three ways to answer.")
  end

  private

    def not_collected_error
      { error: "This phase does not take pictures, so there is nothing to ask for. Tell the " \
               "citizen the contribution goes in without one." }
    end

    def blank_body_error
      { error: "The request needs a sentence of your own saying what the photo is for." }
    end
end
