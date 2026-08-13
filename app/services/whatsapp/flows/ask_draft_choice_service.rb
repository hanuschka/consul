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
      step: Whatsapp::Conversation::Step::AWAITING_CATEGORY,
      body_key: "whatsapp.bot.proposal.ask_category",
      button_label_key: "whatsapp.bot.buttons.choose_category"
    },
    sentiment: {
      step: Whatsapp::Conversation::Step::AWAITING_SENTIMENT,
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

  def self.assign_category(conversation:, label_id:, inbound_message_id: nil)
    new(conversation: conversation, kind: :category)
      .assign(label_id, inbound_message_id)
  end

  def self.assign_sentiment(conversation:, sentiment_id:, inbound_message_id: nil)
    new(conversation: conversation, kind: :sentiment)
      .assign(sentiment_id, inbound_message_id)
  end

  def initialize(conversation:, kind:)
    super(conversation: conversation)
    @kind = kind
  end

  # The tapped answer. Before the record exists the answer goes into the
  # stashed draft data, because the validation it satisfies runs at creation
  # and the record cannot be written until it is satisfied. Afterwards it goes
  # onto the record, where the citizen is correcting a choice rather than
  # supplying a missing one. Either way CompleteDraftService decides what is
  # still outstanding.
  def assign(option_id, inbound_message_id)
    return stash_draft_choice(option_id, inbound_message_id) if pre_creation_draft?

    return call if !assign_to_record(option_id)

    complete_draft(inbound_message_id)
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
      Whatsapp.phrase(choice.fetch(:body_key))
    end

    def rows
      options.map { |option| { id: row_id(option), title: option.name } }
    end

    def send_buttons
      Whatsapp::Send.buttons(account: account, body: body, buttons: rows)
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

    def assign_to_record(option_id)
      if @kind == :category
        Whatsapp::DraftCategory.assign(
          @conversation.draft_resource, @conversation.projekt_phase, option_id
        )
      else
        Whatsapp::DraftSentiment.assign(
          @conversation.draft_resource, @conversation.projekt_phase, option_id
        )
      end
    end

    def pre_creation_draft?
      @conversation.draft_resource.blank? && @conversation.context["draft_data"].present?
    end

    # Written back through the same key the generation call filled, so
    # DraftCategory and DraftSentiment re-validate the answer against the
    # phase exactly as it validated the model's.
    def stash_draft_choice(option_id, inbound_message_id)
      stashed_answer =
        if @kind == :category
          { "projekt_label_ids" => [option_id.to_i] }
        else
          { "sentiment_id" => option_id.to_i }
        end

      draft_data = @conversation.context["draft_data"].to_h.merge(stashed_answer)
      @conversation.merge_context!(draft_data: draft_data)

      complete_draft(inbound_message_id)
    end

    def complete_draft(inbound_message_id)
      Whatsapp::Flows::CompleteDraftService.for_first_draft(
        conversation: @conversation, inbound_message_id: inbound_message_id
      )
    end
end
