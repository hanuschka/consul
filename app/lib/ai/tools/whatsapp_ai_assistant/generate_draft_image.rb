class Ai::Tools::WhatsappAiAssistant::GenerateDraftImage <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Has the portal generate a picture for the draft, from the description the draft " \
              "already carries. Offer it as an alternative when the citizen has no photo of " \
              "their own and this phase takes pictures. It is a slow external call, so tell them " \
              "it is being made before you call this. A failure is not a problem worth stopping " \
              "for: the picture is optional, so say it did not work and go on to publishing."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_IMAGE_CHOICE
  end

  def execute
    return no_draft_error if draft_resource.blank?
    return not_collected_error if !conversation.image_question_available?

    refusal = refuse_if_not_permitted

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
            "contribution can go in with it."
    }
  end

  private

    def not_collected_error
      { error: "This phase does not take pictures, so there is nowhere to put one. Tell the " \
               "citizen the contribution goes in without one." }
    end

    def generation_failed_error
      { error: "The picture could not be generated. Tell the citizen so and offer to go on " \
               "without one, or to use a photo of their own." }
    end
end
