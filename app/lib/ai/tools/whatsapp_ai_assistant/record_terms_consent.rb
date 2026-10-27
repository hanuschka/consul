class Ai::Tools::WhatsappAiAssistant::RecordTermsConsent <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  # The acceptance the web form collects as a checkbox. It is a legal gate, so it is
  # recorded only from an unmistakable answer — and the tools that would violate it
  # refuse on their own rather than relying on this having been called.
  #
  # Asked once per number ever, like the AI disclosure and for the same reason: a
  # regular who re-accepts on every submission stops reading what they accept.
  #
  # Being shown both links is a precondition rather than a sentence in the
  # description, the way severing the account link is: this refuses unless the
  # bot's last message offered `terms_accept`, and the only thing that can offer it
  # is RequestTermsConsent, which sends the links in the same breath.
  description "Records that the citizen has accepted the terms and the privacy policy, which the " \
              "portal requires before anything may be submitted. Call it only when they have " \
              "plainly agreed to the question request_terms_consent asked — a tapped acceptance, " \
              "or words that say yes to that question and nothing else. Never on a message that " \
              "merely carries on the conversation, and never to get a submission moving: this is " \
              "a legal declaration made on their behalf. It refuses until request_terms_consent " \
              "has shown them both links. Once recorded it holds for good, so it is never asked " \
              "twice."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_TERMS_CONSENT
  end

  def execute
    return already_accepted_answer if account.terms_accepted?
    return not_asked_error if !links_shown?

    account.mark_terms_accepted!

    {
      recorded: true,
      hint: "Thank them in one line and carry on with what they were doing — do not restate the " \
            "terms."
    }
  end

  private

    # Read off what the bot's last message really put in front of the citizen, held
    # as it stood when their answer arrived, rather than off the model's account of
    # the conversation.
    def links_shown?
      conversation.confirmation_offered?(:terms_accept)
    end

    def not_asked_error
      { error: "The citizen has not been shown the terms and the privacy policy with the " \
               "question whether they accept, so nothing was recorded. Call " \
               "request_terms_consent — it sends both links and the accept button — and call " \
               "this only after they have answered that question. Do not send the links " \
               "yourself." }
    end

    def already_accepted_answer
      {
        recorded: true,
        already: true,
        hint: "They had already accepted, so do not thank them for it or mention it again."
      }
    end
end
