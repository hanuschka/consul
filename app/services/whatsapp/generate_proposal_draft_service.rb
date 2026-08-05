class Whatsapp::GenerateProposalDraftService < ApplicationService
  def initialize(conversation:, idea_text:)
    @conversation = conversation
    @idea_text = idea_text
  end

  def call
    draft_data = ProposalAiDraft::GenerateDraftService.call(
      idea_text: @idea_text,
      projekt_phase: projekt_phase
    )

    proposal = existing_proposal || build_proposal
    assign_content(proposal, draft_data)
    proposal.save!(validate: false)

    geocode(proposal, draft_data["location"])

    proposal
  end

  private

    def projekt_phase
      @projekt_phase ||= @conversation.projekt_phase
    end

    def author
      @conversation.whatsapp_account.user
    end

    def existing_proposal
      @conversation.proposal
    end

    def build_proposal
      Proposal.new(
        draft: true,
        projekt_phase: projekt_phase,
        author: author
      )
    end

    def assign_content(proposal, draft_data)
      proposal.ai_idea_text = @idea_text
      proposal.ai_image_prompt = draft_data["image_prompt"]
      proposal.resource_terms = true
      proposal.tag_list = draft_data["tag_list"]

      proposal.title = draft_data["title"]
      proposal.description = draft_data["description"]

      assign_sentiment(proposal, draft_data)
      assign_labels(proposal, draft_data)
    end

    def assign_sentiment(proposal, draft_data)
      sentiment_id = draft_data["sentiment_id"]

      return if sentiment_id.blank?
      return if !projekt_phase.sentiments.exists?(id: sentiment_id)

      proposal.sentiment_id = sentiment_id
    end

    def assign_labels(proposal, draft_data)
      generated_ids = Array(draft_data["projekt_label_ids"]).map(&:to_i)

      return if generated_ids.empty?

      valid_ids = projekt_phase.projekt_labels.where(id: generated_ids).pluck(:id)

      return if valid_ids.empty?

      proposal.projekt_label_ids = valid_ids
    end

    def geocode(proposal, location_name)
      return if location_name.blank?

      ProposalAiDraft::GeocodeLocationService.call(proposal:, location_name:)
    end
end
