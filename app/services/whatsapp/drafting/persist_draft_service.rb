class Whatsapp::Drafting::PersistDraftService < ApplicationService
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
      @author ||= Whatsapp::Drafting::SubmissionAuthorService.call(conversation: @conversation)
    end

    def budget_phase?
      projekt_phase.is_a?(::ProjektPhase::BudgetPhase)
    end

    def build_resource
      return build_investment if budget_phase?

      ::Proposal.new(draft: true, projekt_phase: projekt_phase, author: author)
    end

    # An investment reaches its phase through the budget, and a budget here has
    # exactly one heading (Budget has_one :heading, through: :group), so there is
    # nothing for the citizen to choose.
    def build_investment
      budget = projekt_phase.budget

      ::Budget::Investment.new(
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
      resource.ai_idea_text = @conversation.last_idea_text
      resource.ai_image_prompt = @draft_data["image_prompt"]
      resource.tag_list = @draft_data["tag_list"]

      resource.title = @draft_data["title"]
      resource.description = @draft_data["description"]

      # The terms acknowledgement the web form collects, and it is written for
      # both models. It used to be skipped for an investment on the grounds that
      # it "has no such column" — true, but so is a proposal: `resource_terms` is
      # defined by the acceptance validator, not by the schema, and
      # Budget::Investment declares that validator exactly as Proposal does. The
      # guard therefore refused every budget submission after draft generation
      # (CON-2969). What stands behind the value is TermsConsentService, which
      # will not let the flow reach a content prompt without it.
      resource.resource_terms = true

      # A verdict belongs to the text it was reached on, so a rewrite drops it.
      # That is what lets PublishDraftService treat a stored result as "already
      # evaluated, do not pay for it twice".
      resource.ai_evaluation_result = nil

      apply_taxonomy(resource)
    end

    # Valid answers only; each policy leaves an unsatisfied requirement alone
    # rather than clearing it: on a revision the citizen's own earlier choice
    # is already on the record, and a rewrite of the text is not a reason to
    # throw it away.
    def apply_taxonomy(resource)
      Whatsapp::DraftTaxonomy.requirements(projekt_phase).each do |requirement|
        requirement.apply_to(resource, @draft_data)
      end
    end

    # Only where the phase offers a map at all. The pin inferred from the
    # citizen's own wording lands in the same field the web form shows, so a
    # phase with the map switched off has nowhere to render it and no business
    # deriving it — and the citizen is never shown what was guessed.
    #
    # Budget phases included: an investment is `Mappable` like a proposal, and
    # the bot now offers both of them an explicit pin, so inferring one from the
    # text for only one of the two would be the odd case rather than the safe
    # one.
    def geocode(resource)
      return if !@conversation.location_question_available?

      location_name = @draft_data["location"]

      return if location_name.blank?

      ::ProposalAiDraft::GeocodeLocationService.call(mappable: resource, location_name: location_name)
    end
end
