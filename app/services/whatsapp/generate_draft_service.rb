class Whatsapp::GenerateDraftService < ApplicationService
  def initialize(conversation:, idea_text:)
    @conversation = conversation
    @idea_text = idea_text
  end

  def call
    draft_data = ProposalAiDraft::GenerateDraftService.call(
      idea_text: @idea_text,
      projekt_phase: projekt_phase
    )

    resource = @conversation.draft_resource || build_resource
    assign_content(resource, draft_data)
    resource.save!(validate: false)

    geocode(resource, draft_data["location"])

    resource
  end

  private

    def projekt_phase
      @projekt_phase ||= @conversation.projekt_phase
    end

    def author
      @conversation.whatsapp_account.user
    end

    def budget_phase?
      projekt_phase.is_a?(ProjektPhase::BudgetPhase)
    end

    def build_resource
      return build_investment if budget_phase?

      Proposal.new(
        draft: true,
        projekt_phase: projekt_phase,
        author: author
      )
    end

    # An investment reaches its phase through the budget, and a budget here has
    # exactly one heading (Budget has_one :heading, through: :group), so there is
    # nothing for the citizen to choose.
    def build_investment
      budget = projekt_phase.budget

      Budget::Investment.new(
        draft: true,
        budget: budget,
        heading: budget.heading,
        author: author
      )
    end

    def assign_content(resource, draft_data)
      resource.ai_idea_text = @idea_text
      resource.ai_image_prompt = draft_data["image_prompt"]
      resource.tag_list = draft_data["tag_list"]

      resource.title = draft_data["title"]
      resource.description = draft_data["description"]

      # Proposals carry the terms acknowledgement the web form collects; an
      # investment has no such column.
      resource.resource_terms = true if !budget_phase?

      assign_sentiment(resource, draft_data)
      assign_labels(resource, draft_data)
    end

    def assign_sentiment(resource, draft_data)
      sentiment_id = draft_data["sentiment_id"]

      return if sentiment_id.blank?
      return if !projekt_phase.sentiments.exists?(id: sentiment_id)

      resource.sentiment_id = sentiment_id
    end

    def assign_labels(resource, draft_data)
      generated_ids = Array(draft_data["projekt_label_ids"]).map(&:to_i)

      return if generated_ids.empty?

      valid_ids = projekt_phase.projekt_labels.where(id: generated_ids).pluck(:id)

      return if valid_ids.empty?

      resource.projekt_label_ids = valid_ids
    end

    # Proposals only, matching the web flow: the budget investment form has no
    # location step and its generate controller does not geocode either.
    def geocode(resource, location_name)
      return if budget_phase?
      return if location_name.blank?

      ProposalAiDraft::GeocodeLocationService.call(proposal: resource, location_name: location_name)
    end
end
