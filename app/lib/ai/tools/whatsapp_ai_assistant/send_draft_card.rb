class Ai::Tools::WhatsappAiAssistant::SendDraftCard < Ai::Tools::WhatsappAiAssistant::BaseTool
  MAX_ACTIONS = ::Whatsapp::MAX_OFFERED_BUTTONS

  description "Shows the citizen their draft with its picture attached, and up to three buttons " \
              "whose labels you write. This is the only way to show them a picture that only " \
              "exists on an unpublished draft, so use it for the last look before publishing — " \
              "an uploaded photo may be the wrong one, and a generated picture is the part " \
              "nobody has seen. Quote the draft's own title and text in the body, unchanged: it " \
              "is the citizen's contribution, not yours to improve. When the draft has no " \
              "picture, reply_with_actions says the same thing more cheaply. Publishing cannot " \
              "be undone, so a button that publishes must say so. This sends the message itself."

  params do
    string :body,
      description: "What the citizen reads: the draft's title and text quoted as they stand, " \
                   "plus your question. At most 1000 characters."
    array :buttons,
      of: :object,
      description: "Up to three buttons, each {\"action_id\": ..., \"label\": ...}. " \
                   "Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_FINAL_CONFIRMATION
  end

  def execute(body:, buttons:)
    return no_draft_error if draft_resource.blank?
    return blank_body_error if body.to_s.strip.blank?

    offerable = offerable_buttons(buttons)

    return unusable_actions_error if offerable.empty?

    # Both routes to the picture are offered and the transport picks: the uploaded
    # media id when there is one, the blob's own URL as the second chance, and the
    # card without a picture when neither survives. Which of them works depends on
    # what WhatsApp can reach, which is not something a tool knows better than Send
    # does.
    ::Whatsapp::Send.buttons_with_picture(
      account: account,
      body: body.strip,
      buttons: offerable,
      media_id: header_media_id,
      image_url: ::Whatsapp.header_image_url(draft_resource.image&.attachment)
    )

    offered = offerable.map { |button| button[:id] }.join(", ")

    halt("Showed the draft with its picture and the buttons: #{offered}.")
  end

  private

    def offerable_buttons(buttons)
      Array(buttons)
        .filter_map do |button|
          spec = button["action_id"] || button[:action_id]
          label = button["label"] || button[:label]

          ::Whatsapp::AssistantActions.recovery_button(spec: spec, label: label) ||
            ::Whatsapp::AssistantActions.button(
              spec: spec, label: label, conversation: conversation
            )
        end
        .uniq { |button| button[:id] }
        .uniq { |button| button[:title].downcase }
        .first(MAX_ACTIONS)
    end

    # Remembered on the conversation, not just for this send: any later message
    # that leads back here would otherwise download the blob and post the whole
    # picture to WhatsApp again.
    def header_media_id
      stored_media_id || upload_and_store
    end

    # Keyed by the blob it was made from. Revising a draft can replace the picture,
    # and an id remembered against the old one would show the citizen the photo
    # they just changed.
    def stored_media_id
      return if blob_id.blank?
      return if conversation.preview_media_blob_id != blob_id

      conversation.preview_media_id.presence
    end

    def upload_and_store
      media_id = ::Whatsapp::Drafting::UploadDraftImageService.call(resource: draft_resource)

      return if media_id.blank?

      conversation.store_preview_media!(media_id: media_id, blob_id: blob_id)

      media_id
    end

    def blob_id
      return @blob_id if defined?(@blob_id)

      @blob_id = draft_resource.image&.attachment&.blob&.id
    end

    def blank_body_error
      { error: "The card needs the draft quoted in it. Write the body and call this again." }
    end

    def unusable_actions_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :actions_unusable, conversation: conversation, step: conversation.step
      )

      {
        error: "None of those buttons can be offered: an unknown action id or a missing label. " \
               "Name different actions."
      }
    end
end
