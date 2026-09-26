class Ai::Tools::WhatsappAiAssistant::ShowUnlinkForConfirmation <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  # What severing the link does, put in front of the citizen before they answer for
  # it, and the only thing that lets unlink_account run. The statement itself is
  # composed from fixed copy and the confirm button carries a fixed label, because
  # this is the one question in the conversation whose answer turns on a fact about
  # their data — and a fact worded differently from one sampling to the next is a
  # fact a citizen cannot rely on.
  MAX_ACTIONS = ::Whatsapp::MAX_BUTTONS

  description "Tells the citizen what unlinking this number does — that it detaches the number " \
              "only, that their portal account and everything they have published stay, and " \
              "where a real deletion is asked for — and then asks your question with the " \
              "unlink_confirm button and up to two more whose labels you write. The statement " \
              "and the unlink_confirm label are composed and sent for you, so do not write out " \
              "what unlinking does and do not name unlink_confirm among your buttons: pass only " \
              "the question and whatever else you want to offer beside it, such as a way to " \
              "leave the link in place. This is the only thing that arms unlink_account, which " \
              "is refused until it has been called. This sends the messages itself."

  params do
    string :question,
      description: "What you ask the citizen underneath the statement — whether the link should " \
                   "be severed. A sentence or two, in their language, and not a restatement of " \
                   "the statement: they are reading it directly above."
    array :buttons,
      of: :object,
      description: "Up to two further buttons beside the confirm one, each " \
                   "{\"action_id\": ..., \"label\": ...}. The button that severs the link is " \
                   "added for you and comes first. Offer a way to keep the link among these " \
                   "whenever you are asking the question at all. Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_UNLINK_CONFIRMATION
  end

  # Both halves of the fixed copy are checked before anything is built, because the
  # pill records an irreversible offer as it is composed: a confirm button built
  # against a statement that then turns out to be missing would leave the decision
  # log saying the citizen was asked something they were never shown.
  def execute(question:, buttons:)
    return not_linked_answer if user.blank?
    return blank_question_error if question.to_s.strip.blank?

    confirmation = ::Whatsapp::UnlinkPreview.confirmation(conversation: conversation)

    return unavailable_statement_error if confirmation[:block].blank?
    return unavailable_statement_error if confirmation[:confirm_title].blank?

    send_block(confirmation[:block])

    ask(question.strip, offerable_buttons(buttons, confirmation[:confirm_title]))
  end

  private

    def ask(question, offerable)
      ::Whatsapp::Send.buttons(
        account: account, body: question.truncate(::Whatsapp::MAX_INTERACTIVE_BODY_LENGTH),
        buttons: offerable
      )

      offered = offerable.map { |button| button[:id] }.join(", ")

      halt("Told them what unlinking does, then asked with: #{offered}.")
    end

    def send_block(block)
      ::Whatsapp::Send.message_block(account: account, block: block)
    end

    # The confirm pill first and built here, not filtered out of what the model
    # passed: it is unofferable through the ordinary path, so a model naming it would
    # have its pill dropped and the citizen would read the statement under a question
    # with no way to say yes.
    def offerable_buttons(buttons, confirm_title)
      confirm = ::Whatsapp::AssistantActions.platform_button(
        action: :unlink_confirm, title: confirm_title, conversation: conversation
      )

      [confirm, *written_buttons(buttons)]
        .uniq { |button| button[:id] }
        .uniq { |button| button[:title].downcase }
        .first(MAX_ACTIONS)
    end

    def written_buttons(buttons)
      Array(buttons)
        .filter_map do |button|
          spec = button["action_id"] || button[:action_id]
          label = button["label"] || button[:label]

          ::Whatsapp::AssistantActions.offered_button(
            spec: spec, label: label, conversation: conversation
          )
        end
    end

    def not_linked_answer
      { error: "This number is not linked to an account, so there is nothing to unlink and " \
               "nothing to ask about. Say so rather than reporting a failure." }
    end

    def blank_question_error
      { error: "There was no question to ask underneath the statement. Write it and call this " \
               "again — what unlinking does is sent for you." }
    end

    def unavailable_statement_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :actions_unusable, conversation: conversation, step: conversation.step
      )

      {
        error: "The statement about unlinking could not be composed, so nothing was sent and " \
               "nothing was asked. Do not word it yourself: tell the citizen the request could " \
               "not be carried out and offer them something else."
      }
    end
end
