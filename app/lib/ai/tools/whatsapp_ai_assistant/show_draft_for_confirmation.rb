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

  # The way on from the preview used to be the model's to offer, and under the
  # first preview it offered none: the photo and the place were still to come, so
  # "Jetzt einreichen" would have said something that was not going to happen, and
  # what was left were the ways to change the draft. So the first pill is added
  # here and named by what comes next, read off the draft: the photo first, since
  # publishing refuses until it has been asked and not until the place has, then
  # the place, then publishing itself. When the preview goes out stays the model's.
  CONTINUE_LABEL_KEYS = {
    photo: "whatsapp.bot.buttons.draft_continue.photo",
    location: "whatsapp.bot.buttons.draft_continue.location"
  }.freeze

  # What the halt tells the model a tap on the continue pill is for. The tap
  # comes back carrying the label, and the label names the step, so this only
  # names the tool that takes it.
  CONTINUE_TOOLS = {
    photo: "request_photo",
    location: "request_location"
  }.freeze

  description "Shows the citizen their contribution exactly as it will be stored — its title and " \
              "text, which projekt and which participation phase it goes into, and whether a " \
              "photo or a place is attached — and then asks your question with up to three " \
              "buttons. The contribution itself is composed and sent from " \
              "the record, so do not write it out: pass only the question and the buttons. The " \
              "first button is always the way on, added for you and named by what comes next: " \
              "while the photo or the place is still to be asked for, it names that step, and a " \
              "tap on it arrives as action draft_continue — answer it with request_photo or " \
              "request_location as its label says; once nothing is left to ask, it is the " \
              "button that publishes, which cannot be undone and carries a fixed label saying " \
              "so. This is the only thing that lets a draft be published, so publishing is " \
              "refused until it has been called and called again after any change to the " \
              "draft. Where the draft carries " \
              "additions_beyond_idea, it is refused without additions_note, and a button that " \
              "has them taken out is added for you; a tap on it arrives as action " \
              "remove_additions — then rewrite the text without them with revise_draft and show " \
              "it again. This sends the messages itself."

  parameters do
    string :question,
      description: "What you ask the citizen underneath their contribution — whether it is right " \
                   "as it stands, or, while the photo or the place is still to come, whether to " \
                   "go on to it. A sentence or two, in their language, and not a restatement " \
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
      description: "Up to two buttons of your own, each {\"action_id\": ..., \"label\": ...}, " \
                   "after the way on that is added first for you — so do not offer " \
                   "draft_publish: it is that button once nothing is left to ask. Where the " \
                   "draft carries additions_beyond_idea, the button that takes them out follows " \
                   "it and only your first button is kept. " \
                   "#{LABEL_BUDGET_DESCRIPTION} Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}."
    optional :location_declined,
      description: "Only where this phase collects a place and the citizen has said in words " \
                   "that they would rather go without one: true, so the way on no longer leads " \
                   "to the location picker. Null otherwise." do
      boolean
    end
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_FINAL_CONFIRMATION
  end

  def execute(question:, buttons:, additions_note: nil, location_declined: nil)
    return no_draft_error if draft_resource.blank?
    return blank_question_error if question.to_s.strip.blank?
    return missing_additions_note_error if additions? && additions_note.to_s.strip.blank?

    overlong = refuse_overlong_button_labels(buttons)

    return overlong if overlong.present?

    block = ::Whatsapp::DraftPreview.confirmation_block(conversation: conversation)

    return no_draft_error if block.blank?

    repeated = repeated_preview_halt(
      kind: :draft, digest: ::Whatsapp::DraftPreview.digest(conversation: conversation)
    )

    return repeated if repeated.present?

    if ::ActiveModel::Type::Boolean.new.cast(location_declined)
      conversation.record_location_declined!
    end

    offerable = with_platform_buttons(preview_buttons(written_buttons_of(buttons), confirms: []))

    send_block(block)

    ask(question_body(question, additions_note), offerable)
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
        "#{offered}#{noted}.#{continue_note}"
      )
    end

    def continue_note
      tool = CONTINUE_TOOLS[next_step]

      return "" if tool.blank?

      " The first button goes on to the #{next_step}: answer a tap on it (action " \
        "draft_continue) with #{tool}."
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

    # The way on first, then the way to take the additions out, then the model's
    # own — three being all a message holds. None of the model's repeats either:
    # the continue and additions pills are platform-worded, so #preview_buttons
    # has dropped them, and the publishing one is left out by #written_buttons_of.
    def with_platform_buttons(written)
      additions = additions? ? remove_additions_button : nil

      distinct_buttons([forward_button, additions, *written].compact)
    end

    # The model's own pills without the publishing one, which is the way on once
    # nothing is left to ask and is built by #forward_button alone. Dropped by its
    # spec rather than after it is built, so an offer that never goes out is not
    # recorded as an irreversible one.
    def written_buttons_of(buttons)
      Array(buttons).reject do |button|
        action, = ::Whatsapp::AssistantActions.parse(button_value(button, "action_id"))

        CONFIRMS.include?(action)
      end
    end

    def forward_button
      return publish_button if next_step == :publish

      ::Whatsapp::AssistantActions.platform_button(
        action: :draft_continue,
        title: ::Whatsapp::AssistantActions.truncated(
          ::Whatsapp.copy(CONTINUE_LABEL_KEYS.fetch(next_step))
        ),
        conversation: conversation
      )
    end

    def publish_button
      ::Whatsapp::AssistantActions.confirmation_button(
        spec: "draft_publish", label: nil, conversation: conversation, confirms: CONFIRMS
      )
    end

    def next_step
      @next_step ||=
        if !conversation.image_question_settled?
          :photo
        elsif conversation.location_question_open?
          :location
        else
          :publish
        end
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
end
