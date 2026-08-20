class Ai::Tools::WhatsappAiAssistant::ReplyWithActions < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The assistant's own message with the way onward attached. Both halves are its
  # words: the sentence and the labels on the buttons. What it does not choose is
  # the *id* behind a button, because WhatsApp returns the id to the webhook and
  # the inbound side is what turns one back into an action — an invented id has
  # nothing behind it, so the citizen taps and nothing happens, with no error
  # anywhere.
  MAX_ACTIONS = ::Whatsapp::MAX_OFFERED_BUTTONS

  description "Answers the citizen with a short text of your own and up to two tappable " \
              "buttons whose labels you write yourself — the message carries a third of its own, " \
              "the way to the main menu, which you never write and never mention. Prefer it over a plain text reply " \
              "whenever there is an obvious next step: it saves them typing and it says what " \
              "can happen next. Each button needs an action_id from the list below and a label " \
              "of at most 20 characters in the citizen's language. Name a record-backed action " \
              "as \"action-id\" using an id a tool in this conversation returned " \
              "(\"view_projekt-482\", \"notify_toggle-new_comments\"); leave its label empty to " \
              "use the record's own name, which is usually better than a paraphrase of it. " \
              "A button whose action is unknown or whose record no longer exists is dropped. " \
              "For an action that cannot be undone — publishing, supporting, unlinking — the " \
              "label must say what it does (\"Jetzt einreichen\", not \"Weiter\"). This sends " \
              "the message itself: do not write one as well, and do not put a link in it when a " \
              "button already leads there."

  params do
    string :body, description: "The reply text, in the citizen's language. A few short sentences."
    array :buttons,
      of: :object,
      description: "Up to two buttons, most useful first. Each is " \
                   "{\"action_id\": ..., \"label\": ...}. Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}. " \
                   "With a record id after a dash: " \
                   "#{::Whatsapp::AssistantActions.parameterised_action_names.join(", ")}."
  end

  def execute(body:, buttons:)
    return blank_body_error if body.to_s.strip.blank?

    offerable = offerable_buttons(buttons)

    return unusable_actions_error if offerable.empty?

    ::Whatsapp::Send.buttons(account: account, body: body.strip, buttons: offerable)

    halt("Replied to the citizen with buttons: #{offerable.map { |button| button[:id] }.join(", ")}.")
  end

  private

    # Deduplicated twice over, and both are silent-failure prevention rather than
    # policy. WhatsApp refuses the whole message when two buttons share an id, so
    # a repeat would cost the reply rather than the button. Two buttons sharing a
    # *label* are accepted by WhatsApp and indistinguishable to the citizen, which
    # is worse: one of the two gets tapped by accident.
    def offerable_buttons(buttons)
      Array(buttons)
        .filter_map { |button| build(button) }
        .uniq { |button| button[:id] }
        .uniq { |button| button[:title].downcase }
        .first(MAX_ACTIONS)
    end

    # A recovery id keeps its own namespace, read by the inbound side before the
    # catalog's, so it is built by its own path — but the label on it is the
    # model's like every other.
    def build(button)
      spec = button_value(button, "action_id")
      label = button_value(button, "label")

      recovery = ::Whatsapp::AssistantActions.recovery_button(spec: spec, label: label)

      return recovery if recovery.present?

      ::Whatsapp::AssistantActions.button(spec: spec, label: label, conversation: conversation)
    end

    # Providers disagree on whether an object array arrives with string or symbol
    # keys, and a missing label is a legitimate value here rather than an error, so
    # neither shape may raise.
    def button_value(button, key)
      return if !button.respond_to?(:[])

      button[key] || button[key.to_sym]
    end

    def blank_body_error
      { error: "The reply needs text of its own. Write the sentence and call this again." }
    end

    # Names what was wrong without listing the whole vocabulary again — it is
    # already in the parameter's description, and repeating it here is how a retry
    # turns into a third of the turn's tool budget.
    #
    # Recorded as its own event as well as the per-button drops: every button in
    # one reply being unusable is the model working from a wrong idea of the
    # vocabulary, which is a description problem rather than a stale record.
    def unusable_actions_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :actions_unusable, conversation: conversation, step: conversation.step
      )

      {
        error: "None of those buttons can be offered: an unknown action id, a missing label, or " \
               "a record id that does not exist. Answer with plain text instead, or name a " \
               "different action."
      }
    end
end
