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
    awaiting_link_decision: "awaiting_link_decision",
    awaiting_unlink_confirmation: "awaiting_unlink_confirmation",
    awaiting_phase_choice: "awaiting_phase_choice",
    awaiting_idea: "awaiting_idea",
    awaiting_category: "awaiting_category",
    awaiting_sentiment: "awaiting_sentiment",
    awaiting_draft_decision: "awaiting_draft_decision",
    awaiting_image_choice: "awaiting_image_choice",
    awaiting_image_upload: "awaiting_image_upload",
    awaiting_revision: "awaiting_revision",
    awaiting_comment: "awaiting_comment",
    awaiting_notification_settings: "awaiting_notification_settings",
    awaiting_resume_decision: "awaiting_resume_decision"
  }

  # The steps that mean a submission is half-finished. "Stop" aborts one of
  # these; typed at any other moment the same word is the opt-out, so the two
  # readings of the catalog's one keyword are separated here rather than at each
  # call site.
  DRAFTING_STEPS = %w[
    awaiting_idea
    awaiting_category
    awaiting_sentiment
    awaiting_draft_decision
    awaiting_image_choice
    awaiting_image_upload
    awaiting_revision
    awaiting_comment
    awaiting_resume_decision
  ].freeze

  # A draft older than this is not resumed silently: the citizen is asked
  # whether to continue it or start over (catalog C23). Deliberately far longer
  # than WhatsApp's 24-hour service window, so the question is always asked as a
  # reply to the citizen writing in again, never pushed.
  STALE_FLOW_AFTER = 3600.minutes

  def drafting?
    DRAFTING_STEPS.include?(step)
  end

  def stale_flow?
    started_at = context["flow_started_at"]

    return false if started_at.blank?

    Time.zone.parse(started_at) < STALE_FLOW_AFTER.ago
  end

  # Completing keeps the phase so the next idea goes to the same one; resetting
  # drops it so the citizen is asked again.
  def reset_flow!
    update!(cleared_flow_attributes.merge(step: "idle", projekt_phase_id: nil))
  end

  def complete_flow!
    update!(cleared_flow_attributes.merge(step: "idle"))
  end

  # Stamped here rather than by the caller so every entry into a submission —
  # a QR scan, a tapped pill, an assistant tool — shares one clock for the
  # staleness question.
  def start_flow!(projekt_phase)
    update!(
      cleared_flow_attributes.merge(
        step: "awaiting_idea",
        projekt_phase: projekt_phase,
        context: { "flow_started_at" => Time.current.iso8601 }
      )
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
