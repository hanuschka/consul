class Ai::Tools::WhatsappAiAssistant::GenerateDraftImage <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Has the portal generate a picture for the draft, from the description the draft " \
              "already carries. It is one of the three buttons request_photo offers, so a tap on " \
              "that button is what usually leads here — answer it by calling this. Ask for it in " \
              "words only where the citizen says they have no photo of their own without having " \
              "tapped. It is a slow external call, so tell them it is being made before you call " \
              "this. A failure is not a problem worth stopping for: the picture is optional, so " \
              "say it did not work and go on without it. It refuses until request_photo has " \
              "shown the citizen the notices about pictures for this draft."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_IMAGE_CHOICE
  end

  def execute
    return no_draft_error if draft_resource.blank?
    return not_collected_error if !conversation.image_question_available?

    refusal = refuse_if_not_permitted || refuse_without_notices

    return refusal if refusal.present?

    generated = ::Whatsapp::Drafting::AttachDraftImageService.from_generation(
      resource: draft_resource, user: user
    )

    return generation_failed_error if !generated

    # A generated picture is the part of the contribution nobody has seen, so a yes
    # given before it existed cannot stand for the contribution carrying it.
    conversation.revoke_draft_preview_digest!

    {
      attached: true,
      hint: "Show them the picture with show_draft_for_confirmation and ask whether the " \
            "contribution is right with it. The place may still be to come: the preview's " \
            "first button names what follows, so do not ask about publishing before it does."
    }
  end

  private

    # Checked against the draft rather than against the model's reading of the
    # conversation: a typed "mach ein Bild" and a generate pill the model wrote
    # itself both arrived here without the notice that the picture is machine-made
    # ever having been sent.
    def refuse_without_notices
      return if conversation.image_notices_shown?

      {
        error: "The citizen has not been shown the notices about picture rights and " \
               "generated pictures for this draft, so no picture was generated.",
        hint: "Ask for the picture with request_photo — it sends both notices and offers " \
              "generating one as a button. Generate it once they have answered that question."
      }
    end

    def not_collected_error
      { error: "This phase does not take pictures, so there is nowhere to put one. Tell the " \
               "citizen the contribution goes in without one." }
    end

    def generation_failed_error
      { error: "The picture could not be generated. Tell the citizen so and offer to go on " \
               "without one, or to use a photo of their own." }
    end
end
