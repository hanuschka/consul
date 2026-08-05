class WhatsappConversation < ApplicationRecord
  belongs_to :whatsapp_account
  belongs_to :projekt_phase, optional: true
  belongs_to :proposal, optional: true

  enum step: {
    idle: "idle",
    awaiting_link: "awaiting_link",
    awaiting_idea: "awaiting_idea",
    awaiting_draft_decision: "awaiting_draft_decision",
    awaiting_revision: "awaiting_revision"
  }

  def reset_flow!
    update!(
      step: "idle",
      projekt_phase_id: nil,
      proposal_id: nil,
      revisions_count: 0,
      context: {}
    )
  end

  def complete_flow!
    update!(
      step: "idle",
      proposal_id: nil,
      revisions_count: 0,
      context: {}
    )
  end

  def start_flow!(projekt_phase)
    update!(
      step: "awaiting_idea",
      projekt_phase: projekt_phase,
      proposal_id: nil,
      revisions_count: 0,
      context: {}
    )
  end

  def merge_context!(attributes)
    update!(context: context.merge(attributes.stringify_keys))
  end
end
