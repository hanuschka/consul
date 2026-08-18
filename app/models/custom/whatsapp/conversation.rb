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
    AWAITING_PARTICIPATION_PROJEKT = "awaiting_participation_projekt".freeze
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
    awaiting_participation_projekt: Step::AWAITING_PARTICIPATION_PROJEKT,
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
  # whether to continue it or start over (catalog C23).
  #
  # Twelve hours rather than the 3600 minutes this was: at 60 hours someone who
  # left a submission open, slept on it and wrote "Hallo" the next morning was
  # resumed straight into the idea step, and the greeting became the text of
  # their contribution. A night away has to reach the question.
  #
  # Asked as a reply and never pushed, which is a property of where it is read
  # rather than of this number: handle_stale_flow sits in the inbound gate
  # chain, so nothing consults it until the citizen writes in again.
  STALE_FLOW_AFTER = 12.hours

  def drafting?
    DRAFTING_STEPS.include?(step)
  end

  # Whether a reset would cost the citizen something they cannot get back.
  # Asked instead of `drafting?` by the paths that end a *side* conversation —
  # declining an offer, cancelling an unlink — because those may be answered
  # from inside a submission and must not take it with them.
  #
  # Deliberately narrower than `drafting?`, which is a set of steps rather than
  # a statement about work: it counts AWAITING_COMMENT and
  # AWAITING_RESUME_DECISION, where there is no draft to protect, so guarding
  # on it would leave a citizen pinned on a step nothing can clear.
  def unsaved_submission?
    draft_resource.present? || draft_data.present?
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
    return false if flow_started_at.blank?

    Time.zone.parse(flow_started_at) < STALE_FLOW_AFTER.ago
  end

  # Ends a side conversation — a support offer, an unlink question — without
  # ending the submission underneath it. The two wrong answers either side of
  # this are both reachable: reset_flow! takes the draft with it, and leaving
  # the step alone strands the citizen on a question that re-asks itself from
  # StepDispatch on every message (AWAITING_UNLINK_CONFIRMATION is not one of
  # the DRAFTING_STEPS, so nothing else clears it).
  #
  # The step moves to where the submission can be picked up again and the keys
  # the side conversation owns are dropped; everything the draft needs stays.
  def end_side_interaction!
    update!(
      step: resumable_step,
      context: context.except("support_proposal_id", "comment_proposal_id")
    )
  end

  # Both landing steps re-present themselves on the next message rather than
  # acting on it blind — PresentDraftService#handle_decision falls back to
  # showing the card, and AskIdeaService rebuilds from the citizen's own words
  # — so neither can consume a message as an answer to a question it never saw.
  def resumable_step
    return Step::AWAITING_DRAFT_DECISION if draft_resource.present?

    Step::AWAITING_IDEA
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

  # ── Flow context schema ─────────────────────────────────────────────────
  # Every key the `context` jsonb holds, as named accessors — the one place
  # that answers what a key means, who writes it, who reads it, and when it
  # is cleared. Two invariants:
  # - Readers never memoize: reset_flow!/complete_flow!/start_flow! replace
  #   the whole hash, and a cached value would survive the wipe.
  # - Each writer is exactly one merge_context! call, preserving today's
  #   write batching (one UPDATE per moment; keys that must travel together
  #   say why).
  # Every key dies with the flow (the three wipes above) unless its comment
  # names an explicit clear.

  # The staleness clock. Stamped by start_flow! and re-armed on resume
  # (stamp_flow_started!); read by stale_flow? for the C23 resume question.
  def flow_started_at
    context["flow_started_at"]
  end

  # Resuming moves the step without going through start_flow!, so
  # ResumeOrRestartService re-arms the clock here — otherwise the resumed
  # step would be found stale again by the citizen's very next message.
  def stamp_flow_started!
    merge_context!(flow_started_at: Time.current.iso8601)
  end

  # The citizen's own words, written by BuildDraftService before the
  # generation gate so the retry pill can read them back after a failure.
  # Read by the resume question, the duplicate offer's "submit anyway", and
  # PersistDraftService (becomes the record's ai_idea_text).
  def last_idea_text
    context["last_idea_text"]
  end

  # One batched write: a first draft clears the stored correction with the
  # idea, because the retry pill prefers a correction and a stale one would
  # re-apply a change to a draft that no longer exists.
  def store_idea_text!(text)
    merge_context!(last_idea_text: text, last_correction: nil)
  end

  # The change the citizen asked for, written by BuildDraftService on a
  # revision. Read by the retry pill, which prefers it over the original
  # idea: what failed was the edit. Cleared by store_idea_text!.
  def last_correction
    context["last_correction"]
  end

  def store_correction!(text)
    merge_context!(last_correction: text)
  end

  # The two throttle clocks, read back by BuildDraftService#within?. The
  # draft clock is written by store_generated_draft! in the same UPDATE as
  # the draft itself; the screening clock is stamped inside the gate it
  # guards, so an already-screened text never re-arms it.
  def last_draft_at
    context["last_draft_at"]
  end

  def last_screened_at
    context["last_screened_at"]
  end

  def stamp_screened!
    merge_context!(last_screened_at: Time.current.iso8601)
  end

  # The generated draft awaiting persistence — the stash CompleteDraftService
  # reads, asks about, and writes to the record. Its emptiness is the dirty
  # flag: cleared at persist (clear_draft_data!) so a tapped correction on
  # the existing record cannot re-run PersistDraftService.
  def draft_data
    context["draft_data"]
  end

  # One batched write, under the inbound job's advisory lock: the draft, its
  # chat-card summary, and the drafting throttle clock. The summary rides
  # under its own key because the stash is emptied at persist while the
  # cards that quote the summary are sent after.
  def store_generated_draft!(generated)
    merge_context!(
      draft_data: generated.except("card_summary"),
      card_summary: generated["card_summary"],
      last_draft_at: Time.current.iso8601
    )
  end

  # A tapped category/sentiment answer, merged into the stash through the
  # same key the generation call filled so the taxonomy policies re-validate
  # it exactly as they validated the model's.
  def stash_draft_choice!(attributes)
    merge_context!(draft_data: draft_data.to_h.merge(attributes))
  end

  def clear_draft_data!
    merge_context!(draft_data: nil)
  end

  # How often the taxonomy question has been put in a row without a usable
  # answer. Written and read by AskDraftChoiceService, which gives up rather
  # than ask again past its limit: the question re-asks itself on every message
  # that is not a tapped option, so without a count a citizen who cannot answer
  # it has no way out of the step at all.
  #
  # Consecutive, which is why an answered question clears it — the two
  # questions of one submission share the counter, and a citizen who answered
  # the first must not arrive at the second with it half spent.
  def choice_reasks
    context["choice_reasks"].to_i
  end

  # The step and the count in one UPDATE, because asking is one moment. As two
  # named writers it was two transactions per asking, both inside the inbound
  # job's advisory lock — the batching this schema's header asks for.
  def ask_choice!(step)
    update!(step: step, context: context.merge("choice_reasks" => choice_reasks + 1))
  end

  # Nothing to write on the overwhelmingly common path: the counter only exists
  # once a question has gone unanswered, and a tapped option normally clears a
  # key that was never set.
  def clear_choice_reasks!
    return if context["choice_reasks"].blank?

    merge_context!(choice_reasks: nil)
  end

  # The generation call's own shortening of the description, written beside
  # the stash by store_generated_draft! and read by the draft card and the
  # final preview — and by the revision prompt, whose "null = still
  # accurate" contract needs the current one.
  def card_summary
    context["card_summary"]
  end

  # Set by PublishResultService when a taxonomy question is asked
  # mid-publish; tells AskDraftChoiceService to resume the publish instead
  # of rewinding to the draft card. Cleared on the resume.
  def publish_repair?
    context["publish_repair"].present?
  end

  def mark_publish_repair!
    merge_context!(publish_repair: true)
  end

  def clear_publish_repair!
    merge_context!(publish_repair: nil)
  end

  # The duplicate offer, stored beside the step by AskDuplicateChoiceService
  # so a stray typed message re-asks from context instead of re-paying the
  # search and the ranking call. One batched write.
  def duplicate_proposal_ids
    context["duplicate_proposal_ids"]
  end

  def duplicate_row_descriptions
    context["duplicate_row_descriptions"]
  end

  def store_duplicate_offer!(proposal_ids:, row_descriptions:)
    merge_context!(
      duplicate_proposal_ids: proposal_ids,
      duplicate_row_descriptions: row_descriptions
    )
  end

  # The step the revision question was asked from, recorded by
  # AskRevisionService before it overwrites the step — the draft card and
  # the preview owe different steps afterwards. Writes its own step so it
  # can never record anything but the truth.
  def revision_origin
    context["revision_origin"]
  end

  def record_revision_origin!
    merge_context!(revision_origin: step)
  end

  # Whether the location picker was already re-sent once. The second miss
  # publishes: an optional field must not hold a finished submission.
  def location_reminded?
    context["location_reminded"].present?
  end

  def mark_location_reminded!
    merge_context!(location_reminded: true)
  end

  # The uploaded preview picture, remembered by ConfirmSubmissionService
  # keyed by the blob it was made from, so re-sends of the preview do not
  # re-upload — and a revised picture (new blob) invalidates it. One
  # batched write.
  def preview_media_id
    context["preview_media_id"]
  end

  def preview_media_blob_id
    context["preview_media_blob_id"]
  end

  def store_preview_media!(media_id:, blob_id:)
    merge_context!(preview_media_id: media_id, preview_media_blob_id: blob_id)
  end

  # Whether the bot's last message was a question. Written by every asking
  # send (Whatsapp::Send.question/recovery); consumed — read and cleared in
  # the same breath — at the top of the inbound gate chain, so no branch can
  # leave it set and turn an "abbrechen" days later into a cancellation.
  def pending_question?
    context["pending_question"].present?
  end

  def mark_question_pending!
    merge_context!(pending_question: true)
  end

  # Returns whether a question was pending; writes only when one was, so a
  # message with nothing pending costs no UPDATE — exactly the old inline
  # behaviour.
  def consume_pending_question!
    return false if !pending_question?

    merge_context!(pending_question: nil)

    true
  end

  # The proposal the bot last asked about, written by the support/comment
  # prompts and read back by their answer paths and the assistant's tools.
  def support_proposal_id
    context["support_proposal_id"]
  end

  def comment_proposal_id
    context["comment_proposal_id"]
  end

  def store_support_proposal_id!(proposal_id)
    merge_context!(support_proposal_id: proposal_id)
  end

  def store_comment_proposal_id!(proposal_id)
    merge_context!(comment_proposal_id: proposal_id)
  end

  # Whichever of the two the bot last asked about, for the assistant's tools
  # and system prompt — the verbatim two-key fallback both used to spell out.
  def active_proposal_id
    support_proposal_id || comment_proposal_id
  end

  # The ruby_llm message history. Written and read only through
  # Whatsapp::AiAssistant::ChatState, which owns the message shape, the
  # trimming, and the replay.
  def stored_ai_chat
    context["ai_chat"]
  end

  def store_ai_chat!(messages)
    merge_context!(ai_chat: messages)
  end

  private

    # Private on purpose: every context write goes through a named accessor
    # above, so a new key cannot be introduced without declaring what it
    # means, who reads it, and when it clears.
    def merge_context!(attributes)
      update!(context: context.merge(attributes.stringify_keys))
    end

    def cleared_flow_attributes
      { draft_resource: nil, context: {}}
    end
end
