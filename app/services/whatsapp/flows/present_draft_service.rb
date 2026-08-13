class Whatsapp::Flows::PresentDraftService < Whatsapp::Flows::BaseService
  MAX_SCORE_PER_CRITERION = ::ProposalAiDraft::EvaluateSoftCriteriaService::SCORE_MAX

  # Catalog C16 and C18 — the same card, with different copy the second time so
  # a citizen who asked for a change can tell that the change landed. The draft
  # is always shown for active confirmation; nothing here publishes.
  #
  # The phase's criteria are evaluated here rather than at publish, so the score
  # and the feedback land on the card the citizen is deciding on and can be
  # acted on through the revise loop they already have. A hard failure never
  # reaches the card at all.
  # The prefix names a pair of keys — the sentence above the card and the
  # question under it — so the two halves of one piece of copy cannot be given
  # different wordings by two callers.
  def self.first_draft(conversation:, inbound_message_id: nil)
    new(
      conversation: conversation,
      copy_prefix: "whatsapp.bot.proposal.draft",
      inbound_message_id: inbound_message_id
    ).call
  end

  def self.revised_draft(conversation:, inbound_message_id: nil)
    new(
      conversation: conversation,
      copy_prefix: "whatsapp.bot.proposal.draft_revised",
      inbound_message_id: inbound_message_id
    ).call
  end

  # The typed form of the draft card's publish pill, and it has to enter the
  # same steps: a citizen who writes "ja" instead of tapping must still be
  # offered the picture and the pin, not published straight past both. Both
  # questions answer for themselves when their phase has them switched off.
  def self.handle_decision(conversation:, verdict:, correction:, inbound_message_id: nil)
    case verdict
    when :publish
      Whatsapp::Flows::ProposalImageService.ask(
        conversation: conversation, inbound_message_id: inbound_message_id
      )
    when :revise
      Whatsapp::Flows::AskRevisionService.enter(
        conversation: conversation, correction: correction,
        inbound_message_id: inbound_message_id
      )
    else
      first_draft(conversation: conversation)
    end
  end

  def initialize(conversation:, copy_prefix:, inbound_message_id: nil)
    super(conversation: conversation)
    @copy_prefix = copy_prefix
    @inbound_message_id = inbound_message_id
  end

  def call
    return Whatsapp::Flows::CriteriaFeedbackService.call(conversation: @conversation) if hard_failed?

    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_DRAFT_DECISION)

    Whatsapp::Send.buttons(
      account: account,
      body: draft_summary,
      buttons: buttons
    )
  end

  private

    def projekt_phase
      @conversation.projekt_phase
    end

    # Evaluated once per draft: PersistDraftService clears the stored result
    # whenever it rewrites the text, so a result that is present was produced
    # for exactly what the card is about to show — and PublishDraftService
    # reuses it rather than paying for the same call twice.
    def evaluation
      return @evaluation if defined?(@evaluation)

      @evaluation = evaluate
    end

    def evaluate
      return {} if draft_resource.blank?
      return {} if !projekt_phase&.user_resource_criteria&.exists?
      return draft_resource.ai_evaluation_result.to_h if
        draft_resource.ai_evaluation_result.present?

      Whatsapp::Send.typing(message_id: @inbound_message_id)

      ::ProposalAiDraft::EvaluateTwoTierService.call(resource: draft_resource).to_h
    end

    def hard_failed?
      evaluation["stage"] == ::ProposalAiDraft::EvaluateTwoTierService::STAGE_HARD_FAILED
    end

    # Category and sentiment are one block rather than two: they are the same
    # kind of fact about the draft, and a blank line between two short labelled
    # lines reads as two unrelated statements.
    def draft_summary
      [
        Whatsapp::DraftCard.body(
          draft_resource,
          intro_key: "#{@copy_prefix}_intro",
          summary: @conversation.context.dig("draft_data", "card_summary")
        ),
        taxonomy_block,
        evaluation_line,
        Whatsapp.phrase("#{@copy_prefix}_question")
      ].compact_blank.join("\n\n")
    end

    def taxonomy_block
      [category_line, sentiment_line].compact_blank.join("\n")
    end

    # Omitted rather than printed empty when the phase has no categories at all:
    # a "Category:" line with nothing after it reads as a bug.
    def category_line
      category = Whatsapp::DraftCategory.label_for(draft_resource)

      return if category.blank?

      Whatsapp.phrase("whatsapp.bot.proposal.category_line", category: category)
    end

    # The draft carries a sentiment the citizen never chose, assigned by the
    # same model that wrote the text. Shown so the revise loop can correct it
    # before it is published rather than after.
    def sentiment_line
      sentiment = Whatsapp::DraftSentiment.label_for(draft_resource)

      return if sentiment.blank?

      Whatsapp.phrase("whatsapp.bot.proposal.sentiment_line", sentiment: sentiment)
    end

    # Parity with the web flow, which shows the submitter their score and
    # feedback. An empty feedback string is dropped rather than printed as a
    # blank line under a number.
    def evaluation_line
      return if evaluation["stage"] != ::ProposalAiDraft::EvaluateTwoTierService::STAGE_COMPLETED
      return if max_score.zero?

      Whatsapp.phrase(
        "whatsapp.bot.proposal.evaluation_line",
        score: evaluation["total_score"].to_i,
        max_score: max_score,
        feedback: evaluation["overall_feedback"].to_s.squish
      )
    end

    def max_score
      @max_score ||= evaluation.dig("soft", "criteria").to_a.size * MAX_SCORE_PER_CRITERION
    end

    # Three pills is WhatsApp's whole budget, and cancelling is worth one of
    # them here: this is the first message the citizen can answer with anything
    # other than "yes" or "change it", and typing "abbrechen" is only obvious to
    # someone who already knows it works.
    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :draft_publish, label_key: "whatsapp.bot.buttons.draft_publish"
        ),
        Whatsapp::FlowActions.button(
          action: :draft_revise, label_key: "whatsapp.bot.buttons.draft_revise"
        ),
        Whatsapp::Send.recovery_button(:cancel)
      ]
    end
end
