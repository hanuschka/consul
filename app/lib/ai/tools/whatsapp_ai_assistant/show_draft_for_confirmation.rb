class Ai::Tools::WhatsappAiAssistant::ShowDraftForConfirmation <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  # The one thing the citizen has to read before anything is published under their
  # name: the contribution itself. It replaces send_draft_card, which took the body
  # as a parameter and so left the text of the contribution to whichever words the
  # model chose that turn — instructed to quote it unchanged, and perfectly able to
  # shorten, reorder or improve it instead.
  #
  # Nothing about this tool takes the contribution's text. It is composed from the
  # record by Whatsapp::DraftPreview and sent from here, and the only thing the
  # model writes is the question underneath and the labels on the buttons.
  #
  # Two messages rather than one, because an interactive message's body is a
  # quarter of what a plain text message holds and a contribution longer than that
  # would have to be cut to fit — which is the whole thing this exists to prevent.
  MAX_ACTIONS = ::Whatsapp::MAX_OFFERED_BUTTONS

  description "Shows the citizen their contribution exactly as it will be stored — its title and " \
              "text, which projekt and which participation phase it goes into, and whether a " \
              "photo or a place is attached — and then asks your question with up to three " \
              "buttons whose labels you write. The contribution itself is composed and sent from " \
              "the record, so do not write it out: pass only the question and the buttons. This " \
              "is the only thing that lets a draft be published, so publishing is refused until " \
              "it has been called and called again after any change to the draft. Publishing " \
              "cannot be undone, so a button that publishes must say so. This sends the messages " \
              "itself."

  params do
    string :question,
      description: "What you ask the citizen underneath their contribution — whether it should go " \
                   "in as it stands. A sentence or two, in their language, and not a restatement " \
                   "of the contribution: they are reading it directly above."
    array :buttons,
      of: :object,
      description: "Up to three buttons, each {\"action_id\": ..., \"label\": ...}. Offer " \
                   "draft_publish among them whenever you are asking whether it can go in, with " \
                   "a label that says it submits — nothing else arms publishing. " \
                   "Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_FINAL_CONFIRMATION
  end

  def execute(question:, buttons:)
    return no_draft_error if draft_resource.blank?
    return blank_question_error if question.to_s.strip.blank?

    offerable = offerable_buttons(buttons)

    return unusable_actions_error if offerable.empty?

    block = ::Whatsapp::DraftPreview.confirmation_block(conversation: conversation)

    return no_draft_error if block.blank?

    send_block(block)

    ask(question.strip, offerable)
  end

  private

    # The digest is stored before the question is asked rather than after, so a send
    # that fails on the interactive message cannot leave a conversation where the
    # citizen has seen the draft but the record says they have not — and cannot
    # leave the reverse either, which is the dangerous direction.
    def ask(question, offerable)
      conversation.store_draft_preview_digest!(
        ::Whatsapp::DraftPreview.digest(conversation: conversation)
      )

      ::Whatsapp::Send.buttons(
        account: account, body: question.truncate(::Whatsapp::MAX_INTERACTIVE_BODY_LENGTH),
        buttons: offerable
      )

      offered = offerable.map { |button| button[:id] }.join(", ")

      halt("Showed them the contribution as it will be stored, then asked with: #{offered}.")
    end

    # The picture carries the block as its caption wherever the block fits in one,
    # because the two are one thing the citizen reads. Where it does not fit, or
    # where WhatsApp takes neither route to the picture, the picture and the text
    # arrive as their own messages — never the text arriving cut.
    def send_block(block)
      parts = ::Whatsapp::MessageBlock.chunks(block)
      caption = caption_for(parts)

      return if caption.present? && send_picture(caption: caption).present?

      if caption.blank? && picture_available?
        send_picture(caption: nil)
      end

      parts.each { |part| ::Whatsapp::Send.text(account: account, body: part) }
    end

    def caption_for(parts)
      return if !picture_available?
      return if parts.length > 1
      return if parts.first.length > ::Whatsapp::MAX_CAPTION_LENGTH

      parts.first
    end

    def send_picture(caption:)
      ::Whatsapp::Send.picture(
        account: account,
        media_id: header_media_id,
        image_url: ::Whatsapp.header_image_url(draft_resource.image&.attachment),
        caption: caption
      )
    end

    def picture_available?
      ::Whatsapp.usable_header_image?(draft_resource.image&.attachment)
    end

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

    def blank_question_error
      { error: "There was no question to ask underneath the contribution. Write it and call this " \
               "again — the contribution itself is sent for you." }
    end

    def unusable_actions_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :actions_unusable, conversation: conversation, step: conversation.step
      )

      {
        error: "None of those buttons can be offered: an unknown action id or a missing label. " \
               "Name different actions, one of them draft_publish."
      }
    end
end
