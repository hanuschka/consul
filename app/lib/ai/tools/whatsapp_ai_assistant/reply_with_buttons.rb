class Ai::Tools::WhatsappAiAssistant::ReplyWithButtons < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The model chooses between known actions; it never authors one. WhatsApp
  # rejects an unknown button id and refuses more than three buttons, and both
  # of those arrive as a failed send rather than as a validation error, so the
  # allow-list is enforced here instead.
  ALLOWED_ACTIONS = ::Whatsapp::Send::RECOVERY_ACTION_IDS.keys.map(&:to_s).freeze

  description "Answers the citizen with a short text and up to three tappable buttons. " \
              "The buttons may only be: help (show what this bot can do), cancel (abandon " \
              "the current submission), retry (try the last failed step again). Use it whenever " \
              "one of those is the obvious next thing to do. This sends the message itself — do " \
              "not write one as well."

  params do
    string :body, description: "The reply text, in the citizen's language"
    array :action_ids,
      of: :string,
      description: "Buttons to offer, from: #{ALLOWED_ACTIONS.join(', ')}"
  end

  def execute(body:, action_ids:)
    actions = Array(action_ids).map(&:to_s) & ALLOWED_ACTIONS

    return unknown_actions_error if actions.empty?

    ::Whatsapp::Send.recovery(
      conversation: conversation,
      body: body,
      actions: actions.map(&:to_sym)
    )

    halt("Replied to the citizen with buttons: #{actions.join(', ')}.")
  end

  private

    def unknown_actions_error
      {
        error: "None of those buttons exist. Allowed: #{ALLOWED_ACTIONS.join(', ')}. " \
               "Answer with plain text instead if none of them fit."
      }
    end
end
