class Whatsapp::Flows::ConfirmSubmissionService < Whatsapp::Flows::BaseService
  # The last look before anything is published, and the only step that shows
  # the citizen the picture rather than describing it. Reached from the two
  # image branches: an uploaded photo may be the wrong one, and a generated
  # image is the one part of the submission nobody has seen yet.
  #
  # Skipping straight to publishing was the old behaviour and cost the citizen
  # the only chance to catch either — a published proposal cannot be edited
  # from the chat.
  def call
    @conversation.update!(step: "awaiting_final_confirmation")

    # Both routes to the picture are offered and the transport picks: the
    # uploaded media id when there is one, the blob's own URL as the second
    # chance, and the preview without a picture when neither survives. Which of
    # them works depends on what WhatsApp can reach, which is not something this
    # step knows better than Outbound does.
    Whatsapp::Outbound.buttons_with_picture(
      account: account,
      body: body,
      buttons: buttons,
      media_id: header_media_id,
      image_url: header_image_url
    )
  end

  private

    def header_image_url
      ::Whatsapp.header_image_url(draft_resource&.image&.attachment)
    end

    # Remembered on the conversation, not just for this send. Any message at
    # this step that is neither a publish nor a revise word re-sends the
    # preview, and without this each one would download the blob and post the
    # whole picture to WhatsApp again. Cleared with the rest of the context
    # when the flow ends, so it cannot outlive the draft it belongs to.
    def header_media_id
      stored_media_id || upload_and_store
    end

    # Keyed by the blob it was made from. Revising a draft can replace the
    # picture, and an id remembered against the old one would show the citizen
    # the photo they just changed.
    def stored_media_id
      return if blob_id.blank?
      return if @conversation.context["preview_media_blob_id"] != blob_id

      @conversation.context["preview_media_id"].presence
    end

    def upload_and_store
      media_id = Whatsapp::Drafting::UploadDraftImageService.call(resource: draft_resource)

      return if media_id.blank?

      @conversation.merge_context!(preview_media_id: media_id, preview_media_blob_id: blob_id)

      media_id
    end

    def blob_id
      return @blob_id if defined?(@blob_id)

      @blob_id = draft_resource&.image&.attachment&.blob&.id
    end

    def body
      [
        Whatsapp::DraftCard.body(
          draft_resource, intro_key: "whatsapp.bot.proposal.preview_intro"
        ),
        Whatsapp.phrase("whatsapp.bot.proposal.preview_question")
      ].join("\n\n")
    end

    # Three pills, WhatsApp's whole budget. Revising is worth one of them: this
    # is the last look before publishing, and a citizen who spots the wrong
    # photo here would otherwise have to abandon the submission to change it.
    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :submit_final, label_key: "whatsapp.bot.buttons.submit_final"
        ),
        Whatsapp::FlowActions.button(
          action: :draft_revise, label_key: "whatsapp.bot.buttons.draft_revise"
        ),
        Whatsapp::Outbound.recovery_button(:cancel)
      ]
    end
end
