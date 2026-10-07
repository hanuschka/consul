class Ai::Tools::WhatsappAiAssistant::ShowDraftForConfirmation <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

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

  # The only message the publishing pill can sit under, so that tapping it publishes
  # what the citizen has just read rather than asking to show it to them first.
  CONFIRMS = %i[draft_publish submit_final].freeze

  # What the draft proposes beyond the citizen's words, and the way to have it taken
  # out, used to be a sentence the question was asked to contain. The question also
  # carries a similar proposal and the assessment, and where those competed the
  # note was the part that went — so the note has a parameter of its own, refused
  # when missing, and the pill that takes the additions out is added here.
  REMOVE_ADDITIONS_LABEL_KEY = "whatsapp.bot.buttons.remove_additions".freeze

  description "Shows the citizen their contribution exactly as it will be stored — its title and " \
              "text, which projekt and which participation phase it goes into, and whether a " \
              "photo or a place is attached — and then asks your question with up to three " \
              "buttons whose labels you write. The contribution itself is composed and sent from " \
              "the record, so do not write it out: pass only the question and the buttons. This " \
              "is the only thing that lets a draft be published, so publishing is refused until " \
              "it has been called and called again after any change to the draft. Publishing " \
              "cannot be undone, so the button that publishes carries a fixed label saying so and " \
              "whatever you write for it is discarded. Where the draft carries " \
              "additions_beyond_idea, it is refused without additions_note, and a button that " \
              "has them taken out is added for you; a tap on it arrives as action " \
              "remove_additions — then rewrite the text without them with revise_draft and show " \
              "it again. This sends the messages itself."

  parameters do
    string :question,
      description: "What you ask the citizen underneath their contribution — whether it should go " \
                   "in as it stands. A sentence or two, in their language, and not a restatement " \
                   "of the contribution: they are reading it directly above. Ask it as a plain, " \
                   "friendly question even where something above gives them a reason to " \
                   "hesitate, such as a similar proposal: never as though going ahead needed " \
                   "excusing — \"Soll er trotzdem genau so veröffentlicht werden?\" reads as a " \
                   "reproach. Say nothing here about what the draft adds to their words — that " \
                   "is additions_note."
    optional :additions_note,
      description: "Only where the draft carries additions_beyond_idea: one short sentence of " \
                   "your own, in the citizen's language, naming what the draft proposes that " \
                   "they did not say, so they know what goes in under their name and that they " \
                   "can have it taken out. Sent above the question. Leave it empty where the " \
                   "draft carries none — it is then discarded." do
      string
    end
    array :buttons,
      of: :object,
      description: "Up to three buttons, each {\"action_id\": ..., \"label\": ...}. Offer " \
                   "draft_publish among them whenever you are asking whether it can go in — " \
                   "nothing else arms publishing, and its label is written for you, so leave it " \
                   "empty. Where the draft carries additions_beyond_idea, the button that takes " \
                   "them out is added after it and only your first other button is kept. " \
                   "#{LABEL_BUDGET_DESCRIPTION} Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_FINAL_CONFIRMATION
  end

  def execute(question:, buttons:, additions_note: nil)
    return no_draft_error if draft_resource.blank?
    return blank_question_error if question.to_s.strip.blank?
    return missing_additions_note_error if additions? && additions_note.to_s.strip.blank?

    overlong = refuse_overlong_button_labels(buttons)

    return overlong if overlong.present?

    offerable = preview_buttons(buttons, confirms: CONFIRMS)

    return unusable_actions_error if offerable.empty?

    block = ::Whatsapp::DraftPreview.confirmation_block(conversation: conversation)

    return no_draft_error if block.blank?

    repeated = repeated_preview_halt(
      kind: :draft, digest: ::Whatsapp::DraftPreview.digest(conversation: conversation)
    )

    return repeated if repeated.present?

    send_block(block)

    ask(question_body(question, additions_note), with_remove_additions(offerable))
  end

  private

    # The digest is stored before the question is asked rather than after, so a send
    # that fails on the interactive message cannot leave a conversation where the
    # citizen has seen the draft but the record says they have not — and cannot
    # leave the reverse either, which is the dangerous direction.
    def ask(body, offerable)
      conversation.store_draft_preview_digest!(
        ::Whatsapp::DraftPreview.digest(conversation: conversation)
      )

      ::Whatsapp::Send.buttons(account: account, body: body, buttons: offerable)

      offered = offerable.map { |button| button[:id] }.join(", ")
      noted = additions? ? ", under your note on what the draft adds" : ""

      halt(
        "Showed them the contribution as it will be stored, then asked with: " \
        "#{offered}#{noted}."
      )
    end

    # The note goes first so that where the two do not fit together it is the
    # question that gives way: the note is what tells the citizen what they are
    # approving under their name.
    def question_body(question, additions_note)
      note = additions? ? additions_note.to_s.strip : nil

      [note, question.strip]
        .compact_blank
        .join("\n\n")
        .truncate(::Whatsapp::MAX_INTERACTIVE_BODY_LENGTH)
    end

    # Publishing first, then the way to take the additions out, then the first of
    # the model's own — three being all a message holds. The pill is platform-worded,
    # so a model naming it has already had it dropped by #preview_buttons.
    def with_remove_additions(offerable)
      return offerable if !additions?

      publish, others = offerable.partition { |button| publish_button?(button) }

      distinct_buttons([*publish, remove_additions_button, *others].compact)
    end

    # By action rather than by id: the publishing pill's id carries the version it
    # was offered under (Whatsapp::PreviewVersion).
    def publish_button?(button)
      CONFIRMS.include?(::Whatsapp::FlowActions.parse(button[:id])&.dig(:action))
    end

    def remove_additions_button
      ::Whatsapp::AssistantActions.platform_button(
        action: :remove_additions,
        title: ::Whatsapp::AssistantActions.truncated(::Whatsapp.copy(REMOVE_ADDITIONS_LABEL_KEY)),
        conversation: conversation
      )
    end

    def additions?
      return @additions if defined?(@additions)

      @additions = conversation.additions_beyond_idea.present?
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

    def missing_additions_note_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :additions_note_missing, conversation: conversation, step: conversation.step
      )

      {
        error: "This draft carries additions_beyond_idea — things the citizen did not say — and " \
               "there was no additions_note naming them, so nothing was sent.",
        additions_beyond_idea: conversation.additions_beyond_idea,
        hint: "Write additions_note: one short sentence of your own naming them, and call this " \
              "again with everything else unchanged."
      }
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
