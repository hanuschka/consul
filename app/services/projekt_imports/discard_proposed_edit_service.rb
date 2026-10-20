# Marks a pending proposal as declined so the bubble stops offering it and the
# model learns, from the replayed history, that the change was not wanted.
class ProjektImports::DiscardProposedEditService < ApplicationService
  def initialize(ai_chat_message:, proposal_id:)
    @ai_chat_message = ai_chat_message
    @proposal_id = proposal_id.to_s
  end

  def call
    journal = ProjektImports::AiEditJournal.new(ai_chat_message: ai_chat_message)
    proposal = journal.pending_proposal(proposal_id)

    if proposal.blank?
      return ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.proposal_not_found"))
    end

    journal.resolve_proposal!(proposal_id, ProjektImports::AiEditJournal::DISCARDED)

    ServiceResult.success(proposal: proposal)
  end

  private

    attr_reader :ai_chat_message, :proposal_id
end
