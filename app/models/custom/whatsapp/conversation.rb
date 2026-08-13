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

  # Every step the bot can leave a conversation on, as constants so the flow
  # that writes one and the dispatcher that routes on it read the same
  # definition. A typo'd constant raises NameError when its file loads —
  # a typo'd string literal in a `case` never matches and reads as a silently
  # ignored message instead.
  module Step
    IDLE = "idle".freeze
    AWAITING_LINK = "awaiting_link".freeze
    AWAITING_LINK_DECISION = "awaiting_link_decision".freeze
    AWAITING_UNLINK_CONFIRMATION = "awaiting_unlink_confirmation".freeze
    AWAITING_PHASE_CHOICE = "awaiting_phase_choice".freeze
    AWAITING_IDEA = "awaiting_idea".freeze
    AWAITING_DUPLICATE_DECISION = "awaiting_duplicate_decision".freeze
    AWAITING_CATEGORY = "awaiting_category".freeze
    AWAITING_SENTIMENT = "awaiting_sentiment".freeze
    AWAITING_DRAFT_DECISION = "awaiting_draft_decision".freeze
    AWAITING_IMAGE_CHOICE = "awaiting_image_choice".freeze
    AWAITING_IMAGE_UPLOAD = "awaiting_image_upload".freeze
    AWAITING_LOCATION = "awaiting_location".freeze
    AWAITING_FINAL_CONFIRMATION = "awaiting_final_confirmation".freeze
    AWAITING_REVISION = "awaiting_revision".freeze
    AWAITING_COMMENT = "awaiting_comment".freeze
    AWAITING_NOTIFICATION_SETTINGS = "awaiting_notification_settings".freeze
    AWAITING_RESUME_DECISION = "awaiting_resume_decision".freeze
  end

  # The write-side half of the same guard: assigning a step the map does not
  # carry raises ArgumentError instead of persisting it.
  enum step: {
    idle: Step::IDLE,
    awaiting_link: Step::AWAITING_LINK,
    awaiting_link_decision: Step::AWAITING_LINK_DECISION,
    awaiting_unlink_confirmation: Step::AWAITING_UNLINK_CONFIRMATION,
    awaiting_phase_choice: Step::AWAITING_PHASE_CHOICE,
    awaiting_idea: Step::AWAITING_IDEA,
    awaiting_duplicate_decision: Step::AWAITING_DUPLICATE_DECISION,
    awaiting_category: Step::AWAITING_CATEGORY,
    awaiting_sentiment: Step::AWAITING_SENTIMENT,
    awaiting_draft_decision: Step::AWAITING_DRAFT_DECISION,
    awaiting_image_choice: Step::AWAITING_IMAGE_CHOICE,
    awaiting_image_upload: Step::AWAITING_IMAGE_UPLOAD,
    awaiting_location: Step::AWAITING_LOCATION,
    awaiting_final_confirmation: Step::AWAITING_FINAL_CONFIRMATION,
    awaiting_revision: Step::AWAITING_REVISION,
    awaiting_comment: Step::AWAITING_COMMENT,
    awaiting_notification_settings: Step::AWAITING_NOTIFICATION_SETTINGS,
    awaiting_resume_decision: Step::AWAITING_RESUME_DECISION
  }

  # The steps that mean a submission is half-finished. "Stop" aborts one of
  # these; typed at any other moment the same word is the opt-out, so the two
  # readings of the catalog's one keyword are separated here rather than at each
  # call site.
  DRAFTING_STEPS = [
    Step::AWAITING_IDEA,
    Step::AWAITING_DUPLICATE_DECISION,
    Step::AWAITING_CATEGORY,
    Step::AWAITING_SENTIMENT,
    Step::AWAITING_DRAFT_DECISION,
    Step::AWAITING_IMAGE_CHOICE,
    Step::AWAITING_IMAGE_UPLOAD,
    Step::AWAITING_LOCATION,
    Step::AWAITING_FINAL_CONFIRMATION,
    Step::AWAITING_REVISION,
    Step::AWAITING_COMMENT,
    Step::AWAITING_RESUME_DECISION
  ].freeze

  # A draft older than this is not resumed silently: the citizen is asked
  # whether to continue it or start over (catalog C23). Deliberately far longer
  # than WhatsApp's 24-hour service window, so the question is always asked as a
  # reply to the citizen writing in again, never pushed.
  STALE_FLOW_AFTER = 3600.minutes

  def drafting?
    DRAFTING_STEPS.include?(step)
  end

  # What this phase collects besides the text, asked of the conversation because
  # two places each need one of the answers and they must not drift: the step
  # that offers a pin and the drafting service that infers one from the citizen's
  # wording read the same predicate, as do the step that offers a picture and the
  # step a stale conversation re-enters.
  #
  # `feature?` rather than ProjektPhase#resource_map_enabled?, which answers for
  # rendering a map and treats a phase type without the setting as map-enabled.
  # These two mirror the web submission form, where an absent setting collects
  # nothing.
  def location_question_available?
    projekt_phase&.feature?("form.show_map")
  end

  def image_question_available?
    projekt_phase&.feature?("form.allow_attached_image")
  end

  def stale_flow?
    started_at = context["flow_started_at"]

    return false if started_at.blank?

    Time.zone.parse(started_at) < STALE_FLOW_AFTER.ago
  end

  # Completing keeps the phase so the next idea goes to the same one; resetting
  # drops it so the citizen is asked again.
  def reset_flow!
    update!(cleared_flow_attributes.merge(step: Step::IDLE, projekt_phase_id: nil))
  end

  def complete_flow!
    update!(cleared_flow_attributes.merge(step: Step::IDLE))
  end

  # Stamped here rather than by the caller so every entry into a submission —
  # a QR scan, a tapped pill, an assistant tool — shares one clock for the
  # staleness question.
  def start_flow!(projekt_phase)
    update!(
      cleared_flow_attributes.merge(
        step: Step::AWAITING_IDEA,
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
      { draft_resource: nil, context: {}}
    end
end
