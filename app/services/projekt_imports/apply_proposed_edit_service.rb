# Turns a proposal the model journaled into the edit it asked for, on the
# administrator's click. The edit runs through the same editor the immediate
# tools use, so it lands in the journal as a regular entry and the proposal is
# marked applied rather than described twice.
class ProjektImports::ApplyProposedEditService < ApplicationService
  def initialize(ai_chat_message:, proposal_id:)
    @ai_chat_message = ai_chat_message
    @proposal_id = proposal_id.to_s
  end

  def call
    proposal = journal.pending_proposal(proposal_id)
    return failure("proposal_not_found") if proposal.blank?

    details = proposal["details"] || {}

    case proposal["action"]
    when "remove_phase"
      return failure("proposal_stale") if !phase_still_matches?(details)

      editor.remove_phase(details["phase_index"])
    when "replace_content_blocks"
      editor.replace_content_blocks(Array(details["blocks"]))
    else
      return failure("proposal_not_found")
    end

    journal.resolve_proposal!(proposal_id, ProjektImports::AiEditJournal::APPLIED)

    ServiceResult.success(proposal: proposal)
  rescue ProjektImports::AiResultEditor::IndexError,
         ProjektImports::AiResultEditor::ResolvedContentBlocksError
    failure("proposal_stale")
  end

  private

    attr_reader :ai_chat_message, :proposal_id

    def journal
      @journal ||= ProjektImports::AiEditJournal.new(ai_chat_message: ai_chat_message)
    end

    def editor
      @editor ||= ProjektImports::AiResultEditor.new(
        projekt_import: ai_chat_message.ai_chat.resource,
        journal: journal
      )
    end

    # Another edit may have shifted the phase list since the proposal was made;
    # deleting whatever now sits at that index would remove the wrong phase.
    def phase_still_matches?(details)
      phase = editor.phases[details["phase_index"].to_i]
      return false if phase.blank?

      phase["type"] == details["type"] && phase["name"] == details["name"]
    end

    def failure(reason)
      ServiceResult.failure(error: I18n.t("adm.projekts.imports.errors.#{reason}"))
    end
end
