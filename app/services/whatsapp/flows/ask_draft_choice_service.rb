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
  # One service for both because the two questions differ in nothing but which
  # taxonomy they read and which words they use. Those words are spelled out per
  # kind rather than interpolated from it, so a locale key and a step name are
  # still things you can grep for.
  CHOICES = {
    category: {
      step: "awaiting_category",
      body_key: "whatsapp.bot.proposal.ask_category",
      button_label_key: "whatsapp.bot.buttons.choose_category"
    },
    sentiment: {
      step: "awaiting_sentiment",
      body_key: "whatsapp.bot.proposal.ask_sentiment",
      button_label_key: "whatsapp.bot.buttons.choose_sentiment"
    }
  }.freeze

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

    @conversation.update!(step: choice.fetch(:step))

    return send_buttons if options.size <= ::Whatsapp::MAX_BUTTONS

    send_list
  end

  private

    def choice
      CHOICES.fetch(@kind)
    end

    # The one place the two questions genuinely part company: each reads its own
    # taxonomy off the phase.
    def options
      @options ||=
        if @kind == :category
          Whatsapp::DraftCategory.options_for(@conversation.projekt_phase)
        else
          Whatsapp::DraftSentiment.options_for(@conversation.projekt_phase)
        end
    end

    def body
      I18n.t(choice.fetch(:body_key))
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
        button_label: I18n.t(choice.fetch(:button_label_key)),
        empty_body: body
      )
    end

    def row_id(option)
      Whatsapp::FlowActions.id_for(action: @kind, param: option.id)
    end
end
