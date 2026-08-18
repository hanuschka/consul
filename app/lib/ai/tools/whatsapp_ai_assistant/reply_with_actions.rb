class Ai::Tools::WhatsappAiAssistant::ReplyWithActions < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The assistant's own message, in its own words, with the way onward attached.
  # It replaced reply_with_buttons, which could offer three pills — help, cancel,
  # retry — so a reply that wanted to lead somewhere had to describe the route in
  # prose and hope the citizen typed it. Now the catalog is the vocabulary and the
  # sentence is the model's; Whatsapp::AssistantActions decides what may be
  # offered, and the pill's own dispatcher still decides what happens when it is
  # tapped.
  MAX_ACTIONS = ::Whatsapp::MAX_BUTTONS

  description "Answers the citizen with a short text of your own and up to three tappable " \
              "buttons. Prefer it over a plain text reply whenever there is an obvious next " \
              "step: it saves them typing and it says what this bot can do next. Name each " \
              "button by its action id — parameterless ones as they are, record ones as " \
              "\"action-id\" using an id a tool in this conversation returned " \
              "(\"view_projekt-482\", \"notify_toggle-new_comments\"). A button whose id was " \
              "not offered or whose record does not exist is dropped, so name only what you " \
              "know. This sends the message itself — do not write one as well, and do not put " \
              "a link in it when a button already leads there."

  params do
    string :body, description: "The reply text, in the citizen's language. A few short sentences."
    array :action_ids,
      of: :string,
      description: "Up to three buttons, most useful first. Parameterless: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(', ')}. " \
                   "With a record id after a dash: " \
                   "#{::Whatsapp::AssistantActions.parameterised_action_names.join(', ')}."
  end

  def execute(body:, action_ids:)
    return blank_body_error if body.to_s.strip.blank?

    buttons = offerable_buttons(action_ids)

    return unusable_actions_error if buttons.empty?

    ::Whatsapp::Send.question(conversation: conversation, body: body.strip, buttons: buttons)

    halt("Replied to the citizen with buttons: #{buttons.pluck(:id).join(', ')}.")
  end

  private

    # Deduplicated by id: the same pill twice is a message WhatsApp refuses
    # outright, and the model reaching for both "cancel" and "abbrechen" is the
    # kind of near-duplicate that produces one.
    def offerable_buttons(action_ids)
      Array(action_ids)
        .filter_map do |spec|
          ::Whatsapp::AssistantActions.button(spec: spec, conversation: conversation)
        end
        .uniq { |button| button[:id] }
        .first(MAX_ACTIONS)
    end

    def blank_body_error
      { error: "The reply needs text of its own. Write the sentence and call this again." }
    end

    # Names what was wrong without listing the whole vocabulary again — it is
    # already in the parameter's description, and repeating it here is how a
    # retry turns into a third of the turn's tool budget.
    def unusable_actions_error
      {
        error: "None of those buttons can be offered: an unknown action, one that is never " \
               "offered from here, or a record id that does not exist. Answer with plain text " \
               "instead, or name a different action."
      }
    end
end
