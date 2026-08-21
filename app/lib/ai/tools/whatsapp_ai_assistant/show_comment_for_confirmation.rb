class Ai::Tools::WhatsappAiAssistant::ShowCommentForConfirmation <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  # The comment put in front of the citizen before their name goes under it, and
  # the only thing that lets post_comment write anything. Composed from what
  # draft_comment wrote down, so what they read is what will be posted — nothing
  # about this tool takes the comment's text.
  MAX_ACTIONS = ::Whatsapp::MAX_OFFERED_BUTTONS

  description "Shows the citizen the comment written down for them — their words as they wrote " \
              "them, and which proposal it goes on — and then asks your question with up to three " \
              "buttons whose labels you write. The comment itself is composed and sent from what " \
              "draft_comment wrote down, so do not write it out: pass only the question and the " \
              "buttons. This is the only thing that lets a comment be posted, so posting is " \
              "refused until it has been called and called again after any change to the words. " \
              "A posted comment cannot be taken back, so a button that posts must say so. This " \
              "sends the messages itself."

  params do
    string :question,
      description: "What you ask the citizen underneath their comment — whether it should go on " \
                   "the page. A sentence or two, in their language, and not a restatement of the " \
                   "comment: they are reading it directly above."
    array :buttons,
      of: :object,
      description: "Up to three buttons, each {\"action_id\": ..., \"label\": ...}. Offer " \
                   "comment_post among them whenever you are asking whether it should go on the " \
                   "page, with a label that says it posts — nothing else arms posting. " \
                   "Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_COMMENT
  end

  def execute(question:, buttons:)
    return nothing_written_error if conversation.pending_comment.blank?
    return blank_question_error if question.to_s.strip.blank?

    offerable = offerable_buttons(buttons)

    return unusable_actions_error if offerable.empty?

    block = ::Whatsapp::CommentPreview.confirmation_block(conversation: conversation)

    return nothing_written_error if block.blank?

    send_block(block)

    ask(question.strip, offerable)
  end

  private

    # The digest is stored before the question is asked rather than after, so a send
    # that fails on the interactive message cannot leave a conversation where the
    # record says the citizen has seen a comment they have not.
    def ask(question, offerable)
      conversation.store_comment_preview_digest!(
        ::Whatsapp::CommentPreview.digest(conversation: conversation)
      )

      ::Whatsapp::Send.buttons(
        account: account, body: question.truncate(::Whatsapp::MAX_INTERACTIVE_BODY_LENGTH),
        buttons: offerable
      )

      offered = offerable.map { |button| button[:id] }.join(", ")

      halt("Showed them the comment as it will be posted, then asked with: #{offered}.")
    end

    def send_block(block)
      ::Whatsapp::MessageBlock.chunks(block).each do |part|
        ::Whatsapp::Send.text(account: account, body: part)
      end
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

    def nothing_written_error
      { error: "No comment has been written down in this conversation, so there is nothing to " \
               "show. Ask the citizen what they want to say and call draft_comment with their " \
               "own words." }
    end

    def blank_question_error
      { error: "There was no question to ask underneath the comment. Write it and call this " \
               "again — the comment itself is sent for you." }
    end

    def unusable_actions_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :actions_unusable, conversation: conversation, step: conversation.step
      )

      {
        error: "None of those buttons can be offered: an unknown action id or a missing label. " \
               "Name different actions, one of them comment_post."
      }
    end
end
