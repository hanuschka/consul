class Ai::Tools::WhatsappAiAssistant::ReplyWithActions < Ai::Tools::WhatsappAiAssistant::BaseTool
  requires_approval

  # The assistant's own message with the way onward attached. The sentence is its
  # words, and so is nearly every label. What it does not choose is the *id* behind a
  # button, because WhatsApp returns the id to the webhook and the inbound side is
  # what turns one back into an action — an invented id has nothing behind it, so the
  # citizen taps and nothing happens, with no error anywhere. Nor does it choose the
  # words on the handful of pills whose label is a statement rather than a
  # signpost (Whatsapp::AssistantActions::FORCED_LABEL_ACTIONS).
  description "Answers the citizen with a short text of your own and up to three tappable " \
              "buttons, most of whose labels you write yourself. Prefer it " \
              "over a plain text reply whenever there is an obvious next step: it saves them " \
              "typing and it says what can happen next. Each button needs an action_id from the " \
              "list below and a label in the citizen's language of at most " \
              "#{::Whatsapp::AssistantActions::MAX_LABEL_LENGTH} characters counting spaces — " \
              "count them, because a longer one is refused and nothing is sent until it is " \
              "shorter. Name a " \
              "record-backed action as \"action-id\" using an id a tool in this conversation " \
              "returned (\"view_projekt-482\", \"notify_toggle-new_comments\"); leave its label " \
              "empty to use the record's own name, which is usually better than a paraphrase of " \
              "it. A button whose action is unknown or whose record no longer exists is " \
              "dropped. The steps that recur all through a conversation carry fixed labels " \
              "written for you, so the same step always reads the same — leave their label " \
              "empty: #{::Whatsapp::AssistantActions.fixed_label_action_names.join(", ")}. " \
              "Replying about the one proposal or projekt this turn found, opened or acted on, " \
              "the bot puts the buttons its state calls for ahead of yours by itself — support " \
              "or withdraw and comment for a proposal, follow or unfollow for a projekt — and " \
              "yours fill the slots left, so spend yours on the next step. " \
              "Publishing a draft and posting a comment are offered only under their preview, " \
              "by show_draft_for_confirmation and show_comment_for_confirmation, and unlinking " \
              "is not yours to offer at all. This sends the message itself: do not write one as " \
              "well, and do not put a link in it when a button already leads there."

  parameters do
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
    optional :link,
      description: "A page to put under your text, named by the id of the button that " \
                   "opens it (\"phase_open-45\", \"view_contribution-proposal_12\") where a " \
                   "tap note offers one. The bot writes the address in; never write one into " \
                   "body yourself." do
      string
    end
  end

  def execute(body:, buttons:, link: nil)
    refusal = refuse_before_preview

    return refusal if refusal.present?
    return blank_body_error if body.to_s.strip.blank?

    return reply_in_words(body: body.strip) if conversation.mid_question?

    overlong = refuse_overlong_button_labels(buttons)

    return overlong if overlong.present?

    page_url = ::Whatsapp::PillPageUrl.call(link, user: user)

    if link.present? && page_url.blank?
      return unknown_link_error
    end

    offerable = offerable_buttons(buttons)

    return unusable_actions_error if offerable.empty?

    message = send_reply(body: [body.strip, page_url].compact.join("\n\n"), buttons: offerable)

    return send_refused_error if ::Whatsapp::Send.refused?(message)

    button_ids = offerable.map { |button| button[:id] }

    note_typing_hint_offered! if ::Whatsapp::FlowActions.projekt_choice?(button_ids)

    halt(
      [
        "Replied to the citizen with buttons: #{button_ids.join(", ")}.",
        page_url.present? ? "The page #{link} opens was put under the text." : nil,
        ::Whatsapp::AssistantActions.wording_note(wording_offers(offerable))
      ].compact.join(" ")
    )
  end

  private

    # Mid-question the buttons are the question's to show, so this sends words only
    # and says so to the model, which then has no button to name in its reply.
    def reply_in_words(body:)
      message = ::Whatsapp::Send.text(account: account, body: body)

      return send_refused_error if ::Whatsapp::Send.refused?(message)

      halt(
        "Replied in words only: a question is in front of the citizen and it brings its " \
        "own buttons, so none of the buttons you named were sent. Do not name any."
      )
    end

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

    # The state pills of what this turn is about come first, and the model's own fill
    # what is left (Whatsapp::StatePills).
    def offerable_buttons(buttons)
      built = with_pill_records(buttons) do
        Array(buttons).filter_map { |button| build(button) }
      end

      distinct_buttons(::Whatsapp::StatePills.buttons(conversation: conversation) + built)
    end

    # A recovery id keeps its own namespace, read by the inbound side before the
    # catalog's, so it is built by its own path, with a label from the copy.
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

    def blank_body_error
      { error: "The reply needs text of its own. Write the sentence and call this again." }
    end

    def unknown_link_error
      {
        error: "That link names no page this citizen can open now. Leave link out, and say " \
               "there is no page to open rather than writing an address."
      }
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
