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
  # taxonomy policy they read and which words they use. Those words are spelled
  # out per kind rather than interpolated from it, so a locale key and a step
  # name are still things you can grep for.
  CHOICES = {
    category: {
      step: Whatsapp::Conversation::Step::AWAITING_CATEGORY,
      body_key: "whatsapp.bot.proposal.ask_category",
      button_label_key: "whatsapp.bot.buttons.choose_category",
      policy: ->(projekt_phase) { Whatsapp::DraftTaxonomy.category(projekt_phase) }
    },
    sentiment: {
      step: Whatsapp::Conversation::Step::AWAITING_SENTIMENT,
      body_key: "whatsapp.bot.proposal.ask_sentiment",
      button_label_key: "whatsapp.bot.buttons.choose_sentiment",
      policy: ->(projekt_phase) { Whatsapp::DraftTaxonomy.sentiment(projekt_phase) }
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
  # still outstanding — except mid-publish, where the publish resumes instead.
  def assign(option_id, inbound_message_id)
    # A tapped option is an answer whatever happens to it below, so the re-ask
    # count starts again here — the sentiment question that may follow is a
    # question of its own and owes the citizen its own attempts.
    @conversation.clear_choice_reasks!

    return stash_draft_choice(option_id, inbound_message_id) if pre_creation_draft?

    return call if !policy.assign!(@conversation.draft_resource, option_id)

    return resume_publish(inbound_message_id) if @conversation.publish_repair?

    complete_draft(inbound_message_id)
  end

  # How many times one question may be put before the flow gives up on it. The
  # step re-asks on every message that is not a tapped option, so a citizen
  # whose answer never lands — a list their client will not render, an option
  # removed mid-flow — would otherwise be held on it forever, with the same
  # question as the only reply to everything they write.
  MAX_REASKS = 3

  def call
    return if options.empty?
    return abandon if @conversation.choice_reasks >= MAX_REASKS

    @conversation.ask_choice!(choice.fetch(:step))

    return send_buttons if options.size <= ::Whatsapp::MAX_BUTTONS

    send_list
  end

  private

    def choice
      CHOICES.fetch(@kind)
    end

    def policy
      @policy ||= choice.fetch(:policy).call(@conversation.projekt_phase)
    end

    def options
      @options ||= policy.options
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

    # The draft cannot be written without this answer, so there is nothing to
    # hold the citizen on the step for. Cancelling ends it in the one place
    # that says so and offers the way back, rather than in a fourth copy of a
    # question they have already not been able to answer.
    def abandon
      Whatsapp::Flows::CancelService.call(conversation: @conversation)
    end

    def pre_creation_draft?
      @conversation.draft_resource.blank? && @conversation.draft_data.present?
    end

    def stash_draft_choice(option_id, inbound_message_id)
      @conversation.stash_draft_choice!(policy.stash_for(option_id))

      complete_draft(inbound_message_id)
    end

    # The marker means the question was asked mid-publish: the citizen had
    # already confirmed the preview and answered the location question, so
    # their answer resumes the publish instead of rewinding them to the draft
    # card. A stale pill tapped in a later flow carries no marker and can
    # never publish by surprise.
    def resume_publish(inbound_message_id)
      @conversation.clear_publish_repair!

      Whatsapp::Flows::PublishResultService.call(
        conversation: @conversation, inbound_message_id: inbound_message_id
      )
    end

    def complete_draft(inbound_message_id)
      Whatsapp::Flows::CompleteDraftService.for_first_draft(
        conversation: @conversation, inbound_message_id: inbound_message_id
      )
    end
end
