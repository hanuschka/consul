class Ai::Tools::WhatsappAiAssistant::RequestTermsConsent <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  # The terms and the privacy policy, put in front of the citizen before they
  # accept them, and the only thing that lets record_terms_consent run. The
  # statement and both addresses are composed from fixed copy and the accept
  # button carries a fixed label, the way severing the account link works: the
  # answer is a legal declaration, and one given under a sentence the model
  # sampled is one given without the links it was meant to follow.
  #
  # When to ask stays the assistant's decision. What this decides is only that the
  # links are part of the question every time.
  description "Asks the citizen to accept the terms and the privacy policy, which the portal " \
              "requires before anything may be submitted. The statement with both links and the " \
              "terms_accept button are composed and sent for you, so do not write out the terms " \
              "or the links and do not name terms_accept among your buttons: pass only your " \
              "question and whatever else you want to offer beside it, such as a way to decline. " \
              "This is the only thing that arms record_terms_consent, which is refused until it " \
              "has been called. This sends the messages itself."

  params do
    string :question,
      description: "What you ask the citizen underneath the statement — whether they accept. A " \
                   "sentence or two, in their language, and not a restatement of the statement: " \
                   "they are reading it directly above."
    array :buttons,
      of: :object,
      description: "Up to two further buttons beside the accept one, each " \
                   "{\"action_id\": ..., \"label\": ...}. The button that accepts is added for " \
                   "you and comes first. #{LABEL_BUDGET_DESCRIPTION} Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}."
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_TERMS_CONSENT
  end

  # Both halves of the fixed copy are checked before anything is built, because the
  # pill records the offer as it is composed: an accept button built against a
  # statement that then turns out to be missing would leave the decision log saying
  # the citizen was shown links they never saw.
  def execute(question:, buttons:)
    return already_accepted_answer if account.terms_accepted?
    return blank_question_error if question.to_s.strip.blank?

    overlong = refuse_overlong_button_labels(buttons)

    return overlong if overlong.present?

    consent = ::Whatsapp::TermsConsentPreview.confirmation(conversation: conversation)

    return unavailable_statement_error if consent[:block].blank?
    return unavailable_statement_error if consent[:accept_title].blank?

    ::Whatsapp::Send.message_block(account: account, block: consent[:block])

    offerable = buttons_under_statement(
      action: :terms_accept, title: consent[:accept_title], buttons: buttons
    )

    ask(question.strip, offerable)
  end

  private

    def ask(question, offerable)
      ::Whatsapp::Send.buttons(
        account: account,
        body: question.truncate(::Whatsapp::MAX_INTERACTIVE_BODY_LENGTH),
        buttons: offerable
      )

      offered = offerable.map { |button| button[:id] }.join(", ")

      halt("Showed the terms and the privacy policy, then asked with: #{offered}.")
    end

    def already_accepted_answer
      { error: "This citizen has already accepted the terms and the privacy policy, so there " \
               "is nothing to ask. Carry on with what they were doing." }
    end

    def blank_question_error
      { error: "There was no question to ask underneath the statement. Write it and call this " \
               "again — the terms and the links are sent for you." }
    end

    def unavailable_statement_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :actions_unusable, conversation: conversation, step: conversation.step
      )

      {
        error: "The statement about the terms could not be composed, so nothing was sent and " \
               "nothing was asked. Do not word it or send the links yourself: tell the citizen " \
               "it cannot be done right now and offer them something else."
      }
    end
end
