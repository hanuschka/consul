class Whatsapp::GenerateDraftService < ApplicationService
  # The drafting call on its own. It writes nothing: the resource's label and
  # sentiment validations run only at creation, so the record cannot be built
  # until everything they need is in hand, and what the model returned may not
  # be enough. PersistDraftService builds it once it is.
  def initialize(conversation:, idea_text:)
    @conversation = conversation
    @idea_text = idea_text
  end

  def call
    ProposalAiDraft::GenerateDraftService.call(
      idea_text: @idea_text,
      projekt_phase: @conversation.projekt_phase
    ).to_h
  end
end
