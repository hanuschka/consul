class Ai::Tools::WhatsappAiAssistant::SendList < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The one selectable list, replacing the several that each hardcoded their own
  # rows — the projekt browser, the contribution list, the notification settings,
  # the taxonomy picker. What goes in it is the model's; what stays bounded is the
  # id on each row, for the same reason a button's is.
  #
  # A list earns a tool over buttons on two counts: it holds nine rows rather than
  # two, and each row carries a description, which is what lets nine options be
  # named without a sentence above each. The tenth row, the way to start over,
  # is Whatsapp::Send's and arrives on every list without this tool composing it.
  MAX_ROWS = ::Whatsapp::MAX_OFFERED_LIST_ROWS

  # WhatsApp truncates a row description past this without saying so.
  MAX_DESCRIPTION_LENGTH = 72

  description "Sends the citizen a selectable list — up to nine rows, each with a label you write " \
              "and an optional one-line description. Use it instead of buttons whenever there " \
              "are more than three things to choose between, or when each option needs a line " \
              "explaining it. The list carries a tenth row of its own, the way to the main " \
              "menu, which you never write and never mention. Every row needs an action_id " \
              "from the same vocabulary as " \
              "reply_with_actions. Nothing is sent unless every row can be: a row whose " \
              "action is unknown, whose record no longer exists, whose action id repeats " \
              "another row's, or which reads exactly like another row without a description " \
              "to tell the two apart refuses the whole list, because the sentence you wrote " \
              "above it " \
              "names a number of rows and a list that quietly held fewer would contradict it. " \
              "That sentence names how many rows the list holds — not how many there are " \
              "altogether, which belongs in the same sentence in words. A list carries no " \
              "buttons beside it, so any way out of the " \
              "question has to be a row of its own. Rows cannot hold links or markup — put a URL " \
              "in the body above if one is needed. This sends the message itself: do not write " \
              "one as well."

  params do
    string :body,
      description: "The sentence above the list, in the citizen's language, laid out as the " \
                   "style rules require."
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

    offered = Array(rows)
    listed = listable_rows(offered)

    return unusable_rows_error if listed.empty?
    return partial_rows_error(offered: offered, listed: listed) if listed.size < offered.size

    message = ::Whatsapp::Send.list(
      account: account,
      body: body.strip,
      button_label: ::Whatsapp::AssistantActions.truncated(button_label).presence ||
                    I18n.t("whatsapp.bot.buttons.choose"),
      rows: listed
    )

    return send_refused_error if ::Whatsapp::Send.refused?(message)

    row_ids = listed.map { |row| row[:id] }

    note_typing_hint_offered! if ::Whatsapp::FlowActions.projekt_choice?(row_ids)

    halt("Sent a list of #{listed.size} rows: #{row_ids.join(", ")}.")
  end

  private

    def listable_rows(rows)
      built = Array(rows).filter_map { |row| build(row) }.uniq { |row| row[:id] }

      distinguishable(built).first(MAX_ROWS)
    end

    # Told apart by everything the citizen can read on them, which is the label and
    # the line under it. Two rows may carry the same label: a citizen's own history
    # holds whatever they titled their contributions, and two proposals called
    # "Spielplatz" are two proposals — de-duplicating by label alone left one of them
    # out of the list that is meant to be their complete history and named it nowhere
    # else. What the two must not share is both lines at once, because then there is
    # nothing on the screen that says which is which; the caller refuses the whole
    # list over that rather than sending one of them, so nothing is lost quietly.
    def distinguishable(rows)
      rows.uniq { |row| [row[:title].to_s.downcase, row[:description].to_s.downcase] }
    end

    def build(row)
      spec = row_value(row, "action_id")
      label = row_value(row, "label")

      button =
        ::Whatsapp::AssistantActions.recovery_button(spec: spec, label: label) ||
        ::Whatsapp::AssistantActions.button(spec: spec, label: label, conversation: conversation)

      return if button.blank?

      return button if name_only?(button)

      description =
        row_value(row, "description").to_s.squish.presence ||
        ::Whatsapp::AssistantActions.row_description(spec: spec)

      return button if description.blank?

      button.merge(description: description.truncate(MAX_DESCRIPTION_LENGTH))
    end

    # The phase and projekt selections: their row is the name alone. A second line
    # under a projekt's title says nothing that helps the citizen choose between
    # two projekts, and it is repeated back in their own reply. Enforced here
    # rather than asked for in the description, so the model cannot write one.
    def name_only?(button)
      ::Whatsapp::FlowActions.projekt_choice?([button[:id]])
    end

    def row_value(row, key)
      return if !row.respond_to?(:[])

      row[key] || row[key.to_sym]
    end

    def blank_body_error
      { error: "The list needs a sentence above it. Write it and call this again." }
    end

    # Refused rather than sent short, which is the whole reason the de-duplication
    # above no longer drops anything quietly: the sentence over the list is already
    # written by the time this runs, so a list carrying fewer rows than it was given
    # is one message whose two halves disagree on the same screen. The rows that can
    # be sent are named, so the second attempt is this call without the others.
    def partial_rows_error(offered:, listed:)
      {
        error: "Only #{listed.size} of those #{offered.size} rows can be offered — an unknown " \
               "action id, a record that no longer exists, a missing label, an id that repeats " \
               "another row's, two rows reading the same with no description to tell them " \
               "apart, or more than #{MAX_ROWS} rows. Nothing was sent. These are the ones " \
               "that can be: #{listed.map { |row| row[:id] }.join(", ")}. Call this again with " \
               "exactly those — or with a description on each row that needs one — and a " \
               "sentence naming how many you send."
      }
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
