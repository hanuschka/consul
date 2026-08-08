class Whatsapp::Flows::AskDraftChoiceService < Whatsapp::Flows::BaseService
  # Catalog C15 and its sentiment counterpart: the one thing about the draft the
  # citizen has to choose. Asked only when the drafting model came back without
  # a valid answer — it is handed both as closed enums in the same call that
  # writes the title — so this is the exception rather than a step.
  #
  # Three or fewer options fit as buttons, exactly as the catalog draws them;
  # more become a list, because WhatsApp carries at most three buttons and
  # dropping the rest would hide options that exist.
  #
  # One service for both because the two questions differed in nothing but four
  # names, and every one of them derives from the choice itself: the step, the
  # two copy keys and the pill's action are all spelled with it.
  MAX_CHOICE_BUTTONS = 3

  def self.category(conversation:)
    new(conversation: conversation, kind: :category).call
  end

  def self.sentiment(conversation:)
    new(conversation: conversation, kind: :sentiment).call
  end

  def initialize(conversation:, kind:)
    super(conversation: conversation)
    @kind = kind
  end

  def call
    return if options.empty?

    @conversation.update!(step: "awaiting_#{@kind}")

    return send_buttons if options.size <= MAX_CHOICE_BUTTONS

    send_list
  end

  private

    # The one place the two questions genuinely part company: each reads its own
    # taxonomy off the phase. An explicit branch rather than a constant map, so
    # neither module is resolved at load time.
    def options
      return @options if defined?(@options)

      @options =
        if @kind == :category
          Whatsapp::DraftCategory.options_for(@conversation.projekt_phase)
        else
          Whatsapp::DraftSentiment.options_for(@conversation.projekt_phase)
        end
    end

    def body
      I18n.t("whatsapp.bot.proposal.ask_#{@kind}")
    end

    def rows
      options.map { |option| { id: row_id(option), title: option.name } }
    end

    def send_buttons
      Whatsapp::Outbound.buttons(account: account, body: body, buttons: rows)
    end

    def send_list
      Whatsapp::Flows::SendListService.call(
        conversation: @conversation,
        rows: rows,
        body: body,
        button_label: I18n.t("whatsapp.bot.buttons.choose_#{@kind}"),
        empty_body: body
      )
    end

    def row_id(option)
      Whatsapp::FlowActions.id_for(action: @kind, param: option.id)
    end
end
