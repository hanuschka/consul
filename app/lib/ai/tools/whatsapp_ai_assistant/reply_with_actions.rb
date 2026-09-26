class Ai::Tools::WhatsappAiAssistant::ReplyWithActions < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The assistant's own message with the way onward attached. The sentence is its
  # words, and so is nearly every label. What it does not choose is the *id* behind a
  # button, because WhatsApp returns the id to the webhook and the inbound side is
  # what turns one back into an action — an invented id has nothing behind it, so the
  # citizen taps and nothing happens, with no error anywhere. Nor does it choose the
  # words on the handful of pills whose label is a statement rather than a
  # signpost (Whatsapp::AssistantActions::FORCED_LABEL_ACTIONS).
  MAX_ACTIONS = ::Whatsapp::MAX_BUTTONS

  description "Answers the citizen with a short text of your own and up to three tappable " \
              "buttons whose labels you write yourself — all three are yours to fill. Prefer it " \
              "over a plain text reply whenever there is an obvious next step: it saves them " \
              "typing and it says what can happen next. Each button needs an action_id from the " \
              "list below and a label in the citizen's language of at most " \
              "#{::Whatsapp::AssistantActions::MAX_LABEL_LENGTH} characters counting spaces — " \
              "count them, because a longer one is cut and arrives ending in \"…\". Name a " \
              "record-backed action as \"action-id\" using an id a tool in this conversation " \
              "returned (\"view_projekt-482\", \"notify_toggle-new_comments\"); leave its label " \
              "empty to use the record's own name, which is usually better than a paraphrase of " \
              "it. A button whose action is unknown or whose record no longer exists is " \
              "dropped. " \
              "An action that cannot be undone — publishing, commenting — carries a fixed " \
              "label saying what it does, so leave those labels empty; unlinking is not yours " \
              "to offer at all. This sends the message itself: do not write one as well, and do " \
              "not put a link in it when a button already leads there."

  params do
    string :body,
      description: "The reply text, in the citizen's language, laid out as the style rules " \
                   "require."
    array :buttons,
      of: :object,
      description: "Up to three buttons, most useful first. Each is " \
                   "{\"action_id\": ..., \"label\": ...}. Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}. " \
                   "With a record id after a dash: " \
                   "#{::Whatsapp::AssistantActions.parameterised_action_names.join(", ")}."
  end

  def execute(body:, buttons:)
    return blank_body_error if body.to_s.strip.blank?

    offerable = offerable_buttons(buttons)

    return unusable_actions_error if offerable.empty?

    message = send_reply(body: body.strip, buttons: offerable)

    return send_refused_error if ::Whatsapp::Send.refused?(message)

    button_ids = offerable.map { |button| button[:id] }

    note_typing_hint_offered! if ::Whatsapp::FlowActions.projekt_choice?(button_ids)

    halt(
      [
        "Replied to the citizen with buttons: #{button_ids.join(", ")}.",
        ::Whatsapp::AssistantActions.wording_note(wording_offers(offerable))
      ].compact.join(" ")
    )
  end

  private

    # The reply after a submission went in is where the conversation has actually run
    # out: the citizen has finished what they came to do, and what this offers next is
    # an invitation rather than a step they are in the middle of. It is also the only
    # message that can carry the way back, because the confirmation before it is plain
    # text with nothing to tap.
    def send_reply(body:, buttons:)
      if conversation.submission_completed?
        return ::Whatsapp::Send.buttons_with_way_out(
          account: account, body: body, buttons: buttons
        )
      end

      ::Whatsapp::Send.buttons(account: account, body: body, buttons: buttons)
    end

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
    #
    # The words the model asked for are kept against the id the button got, so what
    # it wrote can be compared afterwards with what shipped. Kept here rather than
    # returned alongside the button because #offerable_buttons drops and deduplicates
    # after this: only the buttons that survive that are worth mentioning, and they
    # are known by their id.
    def build(button)
      spec = button_value(button, "action_id")
      label = button_value(button, "label")
      offered = ::Whatsapp::AssistantActions.offered_button(
        spec: spec, label: label, conversation: conversation
      )

      written_labels[offered[:id]] = label if offered.present?

      offered
    end

    def written_labels
      @written_labels ||= {}
    end

    def wording_offers(offerable)
      offerable.map { |button| [written_labels[button[:id]], button[:title]] }
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
        error: "None of those buttons can be offered: an unknown action id, a missing label, " \
               "a record id that does not exist, or #{UNOFFERABLE_RECOVERY_REASON} Answer with " \
               "plain text instead, or name a different action."
      }
    end
end
