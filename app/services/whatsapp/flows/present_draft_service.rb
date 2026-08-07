class Whatsapp::Flows::PresentDraftService < ApplicationService
  DESCRIPTION_PREVIEW_LENGTH = 700
  MAX_SCORE_PER_CRITERION = ProposalAiDraft::EvaluateSoftCriteriaService::SCORE_MAX

  # Catalog C16 and C18 — the same card, with different copy the second time so
  # a citizen who asked for a change can tell that the change landed. The draft
  # is always shown for active confirmation; nothing here publishes.
  #
  # The phase's criteria are evaluated here rather than at publish, so the score
  # and the feedback land on the card the citizen is deciding on and can be
  # acted on through the revise loop they already have. A hard failure never
  # reaches the card at all.
  def self.first_draft(conversation:, inbound_message_id: nil)
    new(
      conversation: conversation,
      copy_key: "whatsapp.bot.proposal.draft",
      inbound_message_id: inbound_message_id
    ).call
  end

  def self.revised_draft(conversation:, inbound_message_id: nil)
    new(
      conversation: conversation,
      copy_key: "whatsapp.bot.proposal.draft_revised",
      inbound_message_id: inbound_message_id
    ).call
  end

  def initialize(conversation:, copy_key: "whatsapp.bot.proposal.draft", inbound_message_id: nil)
    @conversation = conversation
    @copy_key = copy_key
    @inbound_message_id = inbound_message_id
  end

  def call
    return Whatsapp::Flows::CriteriaFeedbackService.call(conversation: @conversation) if hard_failed?

    @conversation.update!(step: "awaiting_draft_decision")

    Whatsapp::Outbound.buttons(
      account: @conversation.whatsapp_account,
      body: draft_summary,
      buttons: buttons
    )
  end

  private

    def draft_resource
      @conversation.draft_resource
    end

    def projekt_phase
      @conversation.projekt_phase
    end

    # Evaluated once per draft: GenerateDraftService clears the stored result
    # whenever it rewrites the text, so a result that is present was produced
    # for exactly what the card is about to show — and PublishDraftService
    # reuses it rather than paying for the same call twice.
    def evaluation
      return @evaluation if defined?(@evaluation)

      @evaluation = evaluate
    end

    def evaluate
      return {} if draft_resource.blank?
      return draft_resource.ai_evaluation_result.to_h if
        draft_resource.ai_evaluation_result.present?
      return {} if !projekt_phase&.user_resource_criteria&.exists?

      Whatsapp::Outbound.typing(message_id: @inbound_message_id)

      ProposalAiDraft::EvaluateTwoTierService.call(resource: draft_resource).to_h
    end

    def hard_failed?
      evaluation["stage"] == ProposalAiDraft::EvaluateTwoTierService::STAGE_HARD_FAILED
    end

    def draft_summary
      [
        I18n.t(@copy_key, title: draft_resource.title, description: plain_description),
        category_line,
        sentiment_line,
        evaluation_line,
        I18n.t("#{@copy_key}_question")
      ].compact_blank.join("\n\n")
    end

    # Omitted rather than printed empty when the phase has no categories at all:
    # a "Category:" line with nothing after it reads as a bug.
    def category_line
      category = Whatsapp::DraftCategory.label_for(draft_resource)

      return if category.blank?

      I18n.t("whatsapp.bot.proposal.category_line", category: category)
    end

    # The draft carries a sentiment the citizen never chose, assigned by the
    # same model that wrote the text. Shown so the revise loop can correct it
    # before it is published rather than after.
    def sentiment_line
      sentiment = Whatsapp::DraftSentiment.label_for(draft_resource)

      return if sentiment.blank?

      I18n.t("whatsapp.bot.proposal.sentiment_line", sentiment: sentiment)
    end

    # Parity with the web flow, which shows the submitter their score and
    # feedback. An empty feedback string is dropped rather than printed as a
    # blank line under a number.
    def evaluation_line
      return if evaluation["stage"] != ProposalAiDraft::EvaluateTwoTierService::STAGE_COMPLETED
      return if max_score.zero?

      I18n.t(
        "whatsapp.bot.proposal.evaluation_line",
        score: evaluation["total_score"].to_i,
        max_score: max_score,
        feedback: evaluation["overall_feedback"].to_s.squish
      )
    end

    def max_score
      @max_score ||= evaluation.dig("soft", "criteria").to_a.size * MAX_SCORE_PER_CRITERION
    end

    def plain_description
      ActionController::Base.helpers
        .strip_tags(draft_resource.description.to_s)
        .squish
        .truncate(DESCRIPTION_PREVIEW_LENGTH)
    end

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :draft_publish, label_key: "whatsapp.bot.buttons.draft_publish"
        ),
        Whatsapp::FlowActions.button(
          action: :draft_revise, label_key: "whatsapp.bot.buttons.draft_revise"
        )
      ]
    end
end
