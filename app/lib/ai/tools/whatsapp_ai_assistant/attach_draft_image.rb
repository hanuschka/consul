class Ai::Tools::WhatsappAiAssistant::AttachDraftImage < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The photo the citizen sent, attached to their draft. It takes no arguments and
  # reads the picture off the conversation instead: an image arrives as a WhatsApp
  # media id, which the protocol layer parks the moment it comes in, and a media id
  # copied by a model is a media id one character away from fetching nothing.
  description "Attaches the photo the citizen has just sent to their draft. Call it as soon as a " \
              "picture arrives while a draft is open — draft_status says whether one is waiting " \
              "and whether this phase collects pictures at all. It reads the picture the citizen " \
              "actually sent, so it needs nothing from you. A picture is always optional: never " \
              "hold a finished draft for one, and where they say they have none, go on. Say " \
              "afterwards, in your own words, that it arrived."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_IMAGE_UPLOAD
  end

  def execute
    return no_draft_error if draft_resource.blank?
    return not_collected_error if !conversation.image_question_available?

    media_id = conversation.shared_image_id

    return nothing_sent_error if media_id.blank?

    refusal = refuse_if_not_permitted

    return refusal if refusal.present?

    attach(media_id)
  end

  private

    # Cleared whether or not it worked. A media id WhatsApp would not give us stays
    # unusable, and leaving it parked would attach the same failure to whatever the
    # citizen does next.
    def attach(media_id)
      attached = ::Whatsapp::Drafting::AttachDraftImageService.from_upload(
        resource: draft_resource, user: user, media_id: media_id
      )

      conversation.clear_shared_image!

      return attach_failed_error if !attached

      # A picture is part of what the citizen confirms and none of it is in the text,
      # so a yes given before this photo arrived was a yes to a contribution without
      # it.
      conversation.revoke_draft_preview_digest!

      {
        attached: true,
        hint: "Show them the contribution with the picture using show_draft_for_confirmation, " \
              "and ask whether it can go in."
      }
    end

    def not_collected_error
      { error: "This phase does not take pictures, so there is nowhere to put one. Tell the " \
               "citizen the contribution goes in without a picture." }
    end

    def nothing_sent_error
      { error: "No picture is waiting. Ask the citizen to send the photo itself rather than " \
               "describing it." }
    end

    # The rights notice belongs with the failure as much as with the offer, because
    # this is where the citizen is asked for the picture a second time.
    def attach_failed_error
      {
        error: "The picture could not be used — it may be too large or in a format the portal " \
               "does not take.",
        hint: "Tell them so and offer to try another one or to go on without a picture. Remind " \
              "them they must hold the rights to any picture they send.",
        size_limit_megabytes: ::Image.max_file_size
      }
    end
end
