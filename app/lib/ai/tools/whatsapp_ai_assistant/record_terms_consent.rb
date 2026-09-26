class Ai::Tools::WhatsappAiAssistant::RecordTermsConsent <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  # The acceptance the web form collects as a checkbox. It is a legal gate, so it is
  # recorded only from an unmistakable answer — and the tools that would violate it
  # refuse on their own rather than relying on this having been called.
  #
  # Asked once per number ever, like the AI disclosure and for the same reason: a
  # regular who re-accepts on every submission stops reading what they accept.
  description "Records that the citizen has accepted the terms and the privacy policy, which the " \
              "portal requires before anything may be submitted. Call it only when they have " \
              "plainly agreed after being shown both links — a tapped acceptance, or words that " \
              "say yes to that question and nothing else. Never on a message that merely carries " \
              "on the conversation, and never to get a submission moving: this is a legal " \
              "declaration made on their behalf. Once recorded it holds for good, so it is never " \
              "asked twice."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_TERMS_CONSENT
  end

  def execute
    return already_accepted_answer if account.terms_accepted?

    account.mark_terms_accepted!

    {
      recorded: true,
      hint: "Thank them in one line and carry on with what they were doing — do not restate the " \
            "terms."
    }
  end

  private

    def already_accepted_answer
      {
        recorded: true,
        already: true,
        hint: "They had already accepted, so do not thank them for it or mention it again."
      }
    end
end
