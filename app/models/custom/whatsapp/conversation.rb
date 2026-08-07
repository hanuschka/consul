class Whatsapp::Conversation < ApplicationRecord
  belongs_to :whatsapp_account, class_name: "Whatsapp::Account", inverse_of: :whatsapp_conversation
  belongs_to :projekt_phase, class_name: "::ProjektPhase", optional: true

  # Every step and tool needs the account, and most of them only need the
  # citizen behind it. Nil until the number is linked, which is the state each
  # caller already has to answer for.
  delegate :user, to: :whatsapp_account

  # A proposal in a proposal phase, a Budget::Investment in a budget phase. The
  # bot flow is the same either way, so the draft it is working on is held in
  # one slot rather than a column per resource.
  #
  # The `draft` condition has to be unscoped: both models carry
  # `default_scope { where(draft: false) }`, and everything this association
  # points at is by definition still a draft. Without it the association
  # resolves to nil on the next inbound message — which is a different request,
  # so it reads from the database rather than the association cache.
  belongs_to :draft_resource,
    -> { unscope(where: :draft) },
    polymorphic: true,
    optional: true

  enum step: {
    idle: "idle",
    awaiting_link: "awaiting_link",
    awaiting_phase_choice: "awaiting_phase_choice",
    awaiting_idea: "awaiting_idea",
    awaiting_draft_decision: "awaiting_draft_decision",
    awaiting_revision: "awaiting_revision"
  }

  # Completing keeps the phase so the next idea goes to the same one; resetting
  # drops it so the citizen is asked again.
  def reset_flow!
    update!(cleared_flow_attributes.merge(step: "idle", projekt_phase_id: nil))
  end

  def complete_flow!
    update!(cleared_flow_attributes.merge(step: "idle"))
  end

  def start_flow!(projekt_phase)
    update!(
      cleared_flow_attributes.merge(step: "awaiting_idea", projekt_phase: projekt_phase)
    )
  end

  def merge_context!(attributes)
    update!(context: context.merge(attributes.stringify_keys))
  end

  private

    def cleared_flow_attributes
      { draft_resource: nil, revisions_count: 0, context: {}}
    end
end
