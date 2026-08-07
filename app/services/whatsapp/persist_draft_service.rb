class Whatsapp::PersistDraftService < ApplicationService
  # Writes the drafting model's output to a real record, validated. The bot used
  # to save past the resource's own validations because a half-finished draft
  # cannot satisfy them; the flow now withholds the record until it can, so the
  # same rules the web form enforces apply to a submission made by chat.
  #
  # Called once the citizen has answered whatever the model left open, so the
  # draft data here is complete by construction — a validation failure is a real
  # problem with the text and is reported as one.
  def initialize(conversation:, draft_data:)
    @conversation = conversation
    @draft_data = draft_data.to_h
  end

  def call
    resource = @conversation.draft_resource || build_resource

    assign_content(resource)
    resource.save!

    geocode(resource)

    resource
  end

  private

    def projekt_phase
      @projekt_phase ||= @conversation.projekt_phase
    end

    def author
      @author ||= Whatsapp::SubmissionAuthorService.call(
        conversation: @conversation,
        projekt_phase: projekt_phase
      )
    end

    def budget_phase?
      projekt_phase.is_a?(ProjektPhase::BudgetPhase)
    end

    def build_resource
      return build_investment if budget_phase?

      Proposal.new(draft: true, projekt_phase: projekt_phase, author: author)
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

    # Read from the conversation rather than passed in: a category answer
    # persists the same draft a message later, and the citizen's original words
    # are what BuildDraftService already stored there to make a retry possible.
    def assign_content(resource)
      resource.ai_idea_text = @conversation.context["last_idea_text"]
      resource.ai_image_prompt = @draft_data["image_prompt"]
      resource.tag_list = @draft_data["tag_list"]

      resource.title = @draft_data["title"]
      resource.description = @draft_data["description"]

      # Proposals carry the terms acknowledgement the web form collects; an
      # investment has no such column.
      resource.resource_terms = true if !budget_phase?

      # A verdict belongs to the text it was reached on, so a rewrite drops it.
      # That is what lets PresentDraftService and PublishDraftService treat a
      # stored result as "already evaluated, do not pay for it twice".
      resource.ai_evaluation_result = nil

      assign_sentiment(resource)
      assign_labels(resource)
    end

    def assign_sentiment(resource)
      sentiment_id = Whatsapp::DraftRequirements.valid_sentiment_id(@draft_data, projekt_phase)

      return if sentiment_id.blank?

      resource.sentiment_id = sentiment_id
    end

    # Left alone rather than cleared when the model returned nothing usable: on
    # a revision the citizen's own earlier choice is already on the record, and
    # a rewrite of the text is not a reason to throw it away.
    def assign_labels(resource)
      label_ids = Whatsapp::DraftRequirements.valid_label_ids(@draft_data, projekt_phase)

      return if label_ids.empty?

      resource.projekt_label_ids = label_ids
    end

    # Proposals only, matching the web flow: the budget investment form has no
    # location step and its generate controller does not geocode either.
    def geocode(resource)
      return if budget_phase?

      location_name = @draft_data["location"]

      return if location_name.blank?

      ProposalAiDraft::GeocodeLocationService.call(proposal: resource, location_name: location_name)
    end
end
