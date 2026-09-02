class Ai::Tools::WhatsappAiAssistant::SendList < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The one selectable list, replacing the several that each hardcoded their own
  # rows — the projekt browser, the contribution list, the notification settings,
  # the taxonomy picker. What goes in it is the model's; what stays bounded is the
  # id on each row, for the same reason a button's is.
  #
  # A list earns a tool over buttons on two counts: it holds nine rows rather than
  # two, and each row carries a description, which is what lets nine options be
  # named without a sentence above each. The tenth row, the way to the main menu,
  # is Whatsapp::Send's and arrives on every list without this tool composing it.
  MAX_ROWS = ::Whatsapp::MAX_OFFERED_LIST_ROWS

  # WhatsApp truncates a row description past this without saying so.
  MAX_DESCRIPTION_LENGTH = 72

  # The phase and projekt selections: their row is the name alone. A second line
  # under a projekt's title says nothing that helps the citizen choose between
  # two projekts, and it is repeated back in their own reply. Enforced here
  # rather than asked for in the description, so the model cannot write one.
  NAME_ONLY_ACTIONS = %i[view_projekt participate_projekt idea_start discover_category].freeze

  description "Sends the citizen a selectable list — up to nine rows, each with a label you write " \
              "and an optional one-line description. Use it instead of buttons whenever there " \
              "are more than three things to choose between, or when each option needs a line " \
              "explaining it. The list carries a tenth row of its own, the way to the main " \
              "menu, which you never write and never mention. Every row needs an action_id " \
              "from the same vocabulary as " \
              "reply_with_actions; a row whose action is unknown or whose record no longer " \
              "exists is dropped. A list carries no buttons beside it, so any way out of the " \
              "question has to be a row of its own. Rows cannot hold links or markup — put a URL " \
              "in the body above if one is needed. This sends the message itself: do not write " \
              "one as well."

  params do
    string :body, description: "The sentence above the list, in the citizen's language."
    string :button_label,
      description: "What the button that opens the list says, at most 20 characters " \
                   "(\"Projekt wählen\", \"Auswählen\")."
    array :rows,
      of: :object,
      description: "Up to nine rows, most useful first. Each is {\"action_id\": ..., " \
                   "\"label\": ..., \"description\": ...}, where description is optional. " \
                   "Parameterless action ids: " \
                   "#{::Whatsapp::AssistantActions.offerable_action_names.join(", ")}. " \
                   "With a record id after a dash: " \
                   "#{::Whatsapp::AssistantActions.parameterised_action_names.join(", ")}."
  end

  def execute(body:, button_label:, rows:)
    return blank_body_error if body.to_s.strip.blank?

    listed = listable_rows(rows)

    return unusable_rows_error if listed.empty?

    ::Whatsapp::Send.list(
      account: account,
      body: body.strip,
      button_label: ::Whatsapp::AssistantActions.truncated(button_label).presence ||
                    I18n.t("whatsapp.bot.buttons.choose"),
      rows: listed
    )

    halt("Sent a list of #{listed.size} rows: #{listed.map { |row| row[:id] }.join(", ")}.")
  end

  private

    def listable_rows(rows)
      Array(rows)
        .filter_map { |row| build(row) }
        .uniq { |row| row[:id] }
        .uniq { |row| row[:title].downcase }
        .first(MAX_ROWS)
    end

    def build(row)
      spec = row_value(row, "action_id")
      label = row_value(row, "label")

      button =
        ::Whatsapp::AssistantActions.recovery_button(spec: spec, label: label) ||
        ::Whatsapp::AssistantActions.button(spec: spec, label: label, conversation: conversation)

      return if button.blank?

      return button if name_only?(button)

      description = row_value(row, "description").to_s.squish

      return button if description.blank?

      button.merge(description: description.truncate(MAX_DESCRIPTION_LENGTH))
    end

    def name_only?(button)
      action = ::Whatsapp::FlowActions.parse(button[:id])&.dig(:action)

      NAME_ONLY_ACTIONS.include?(action)
    end

    def row_value(row, key)
      return if !row.respond_to?(:[])

      row[key] || row[key.to_sym]
    end

    def blank_body_error
      { error: "The list needs a sentence above it. Write it and call this again." }
    end

    def unusable_rows_error
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :actions_unusable, conversation: conversation, step: conversation.step
      )

      {
        error: "None of those rows can be offered: an unknown action id, a missing label, or a " \
               "record id that does not exist. Answer with plain text instead, or name " \
               "different actions."
      }
    end
end
