class Whatsapp::Conversation < ApplicationRecord
  belongs_to :whatsapp_account, class_name: "Whatsapp::Account", inverse_of: :whatsapp_conversation
  belongs_to :projekt_phase, class_name: "::ProjektPhase", optional: true

  # Every tool needs the account, and most of them only need the citizen behind
  # it. Nil until the number is linked, which is the state each caller already has
  # to answer for.
  delegate :user, to: :whatsapp_account

  # A proposal in a proposal phase, a Budget::Investment in a budget phase. The
  # submission works the same either way, so the draft it is working on is held in
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

  # ── The step column is a diagnostic, not control flow ───────────────────
  # Nothing reads this to decide what to do any more: the assistant owns the
  # order of the conversation, and what it does next follows from the tools it is
  # given and the state it is told. What the column still answers is "what was
  # this conversation doing when it broke", which is the only cheap answer to
  # that question — and it is what the /adm dialog view renders and what every
  # log line already written says. It is stamped from the last tool that ran (see
  # Ai::Tools::WhatsappAiAssistant::BaseTool#diagnostic_step).
  #
  # Kept as an enum so a value nothing translates cannot be persisted, and every
  # value stays declared even where no tool stamps one any more: rows written by
  # the scripted flow still hold them, /adm looks each one up under
  # adm.whatsapp.steps, and the dialog filter offers the whole map. Retiring a
  # value would break the reading of conversations that already happened.
  module Step
    IDLE = "idle".freeze
    AWAITING_LINK = "awaiting_link".freeze
    AWAITING_LINK_DECISION = "awaiting_link_decision".freeze
    AWAITING_UNLINK_CONFIRMATION = "awaiting_unlink_confirmation".freeze
    AWAITING_PHASE_CHOICE = "awaiting_phase_choice".freeze
    AWAITING_PARTICIPATION_PROJEKT = "awaiting_participation_projekt".freeze
    AWAITING_TERMS_CONSENT = "awaiting_terms_consent".freeze
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
    AWAITING_CONTINUE_DECISION = "awaiting_continue_decision".freeze
  end

  enum step: {
    idle: Step::IDLE,
    awaiting_link: Step::AWAITING_LINK,
    awaiting_link_decision: Step::AWAITING_LINK_DECISION,
    awaiting_unlink_confirmation: Step::AWAITING_UNLINK_CONFIRMATION,
    awaiting_phase_choice: Step::AWAITING_PHASE_CHOICE,
    awaiting_participation_projekt: Step::AWAITING_PARTICIPATION_PROJEKT,
    awaiting_terms_consent: Step::AWAITING_TERMS_CONSENT,
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
    awaiting_resume_decision: Step::AWAITING_RESUME_DECISION,
    awaiting_continue_decision: Step::AWAITING_CONTINUE_DECISION
  }

  # Written after a tool has run, never before and never read back. Silently
  # ignores anything the enum does not carry: a diagnostic that can raise is a
  # diagnostic that costs the citizen their reply.
  def record_step!(diagnostic_step)
    return if diagnostic_step.blank?
    return if !self.class.steps.key?(diagnostic_step.to_s)
    return if step == diagnostic_step.to_s

    update!(step: diagnostic_step)
  rescue StandardError => e
    Rails.logger.info("[Whatsapp] step diagnostic failed: #{e.class} - #{e.message}")

    nil
  end

  # Whether a reset would cost the citizen something they cannot get back. This is
  # the one predicate the write tools guard on: the stashed draft data before the
  # record exists, the record itself afterwards.
  def unsaved_submission?
    draft_resource.present? || draft_data.present?
  end

  # What this phase collects besides the text, asked of the conversation because
  # two places each need one of the answers and they must not drift: the tool that
  # offers a pin and the drafting call that infers one from the citizen's wording
  # read the same predicate, as does the tool that offers a picture.
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

  # Whether the question is still worth putting — the phase collects it *and* the
  # citizen has not already answered it unasked in the message that opened the
  # submission.
  def image_question_pending?
    image_question_available? && !photo_declined?
  end

  def location_question_pending?
    location_question_available? && !location_stated?
  end

  # Everything the submission collected, dropped. The phase goes with it, so the
  # next idea is asked about again.
  #
  # The assistant's stored history survives all three of these wipes, and that is
  # the change the step machine's retirement forces: the history is now the only
  # thing carrying continuity between two turns, so a citizen who abandons one
  # submission and starts talking about something else must not find the bot with
  # no memory of the last ten minutes. It used to be wiped here, which the step
  # column made survivable.
  def discard_draft!
    update!(draft_resource: nil, projekt_phase_id: nil, context: retained_context)
  end

  # The same, keeping the phase: a citizen who just published usually has their
  # next idea for the same projekt.
  def complete_draft!
    update!(draft_resource: nil, context: retained_context)
  end

  # Entering a submission. The context is replaced rather than merged — a new
  # submission has settled nothing — except for the assistant's own stored
  # history, which is the conversation and outlives any one draft in it.
  def start_draft!(new_projekt_phase)
    update!(
      draft_resource: nil,
      projekt_phase: new_projekt_phase,
      context: retained_context
    )
  end

  # Leaving the projekt without abandoning anything. The phase stops being the
  # one the conversation is about and nothing else moves: the draft stash, the
  # proposal the bot last spoke about, a waiting photo or pin and the offers the
  # last message made all stay. That is deliberate — this is the way out of a
  # projekt that sits on every single message the bot sends, so it may not be a
  # path that destroys a half-written contribution. Whoever calls it has already
  # established there is nothing to lose (#unsaved_submission?), and discarding,
  # where that is what the citizen meant, stays the one implementation in
  # AbortSubmission.
  def leave_projekt!
    return if projekt_phase_id.blank?

    update!(projekt_phase_id: nil)
  end

  # ── Draft context schema ────────────────────────────────────────────────
  # Every key the `context` jsonb holds, as named accessors — the one place that
  # answers what a key means, who writes it, who reads it, and when it is
  # cleared. Two invariants:
  # - Readers never memoize: discard_draft!/complete_draft!/start_draft! replace
  #   the whole hash, and a cached value would survive the wipe.
  # - Each writer is exactly one merge_context! call, preserving one UPDATE per
  #   moment; keys that must travel together say why.

  # The citizen's own words, written before the drafting call so a retry can read
  # them back after a failure. Read by PersistDraftService, which makes them the
  # record's ai_idea_text.
  def last_idea_text
    context["last_idea_text"]
  end

  def store_idea_text!(text)
    merge_context!(last_idea_text: text)
  end

  # The two throttle clocks, read back by the drafting tool. The draft clock is
  # written by store_generated_draft! in the same UPDATE as the draft itself; the
  # screening clock is stamped inside the gate it guards, so an already-screened
  # text never re-arms it.
  def last_draft_at
    context["last_draft_at"]
  end

  def last_screened_at
    context["last_screened_at"]
  end

  def stamp_screened!
    merge_context!(last_screened_at: Time.current.iso8601)
  end

  # The generated draft awaiting persistence — the stash the completion gate
  # reads, asks about, and writes to the record. Its emptiness is the dirty flag:
  # cleared at persist so a later taxonomy correction on the existing record
  # cannot re-run PersistDraftService.
  def draft_data
    context["draft_data"]
  end

  # What the citizen answered before being asked, read off their own words by the
  # drafting call. Written by store_generated_draft!; read by the two tools that
  # would otherwise ask again.
  SETTLED_SLOT_KEYS = %w[photo_declined location_stated].freeze

  # One batched write, under the inbound job's advisory lock: the draft, the
  # questions the citizen already answered unasked, and the drafting throttle
  # clock. The settled slots ride under their own key because the stash is emptied
  # at persist while the photo and location questions are asked after the record
  # exists.
  #
  # Replaced rather than merged, which matters on a revision: a revision reports
  # no slots, so the slots clear. That is deliberate — carried over, a declined
  # photo would hold for the life of the submission, and a citizen who changed
  # their mind while revising would have had no way to send one at all.
  def store_generated_draft!(generated)
    merge_context!(
      draft_data: generated.except(*SETTLED_SLOT_KEYS),
      settled_slots: generated.slice(*SETTLED_SLOT_KEYS),
      last_draft_at: Time.current.iso8601
    )
  end

  def settled_slots
    context["settled_slots"].to_h
  end

  # Both default false on every path that cannot answer — a revision, a provider
  # that returned nothing. False is the safe direction: asking a question twice
  # costs a message, skipping one the citizen never answered costs them the photo
  # they meant to send.

  # The same slot answered by a tapped button rather than by the citizen's opening
  # message. Written by Inbound::ProcessMessageService, read by draft_status, and
  # cleared with the rest of the slots on the next draft or revision.
  def settle_slot!(slot)
    return if !SETTLED_SLOT_KEYS.include?(slot.to_s)

    merge_context!(settled_slots: settled_slots.merge(slot.to_s => true))
  end

  def photo_declined?
    settled_slots["photo_declined"] == true
  end

  def location_stated?
    settled_slots["location_stated"] == true
  end

  # A taxonomy answer merged into the stash through the same key the generation
  # call filled, so the policies re-validate it exactly as they validated the
  # model's.
  def stash_draft_choice!(attributes)
    merge_context!(draft_data: draft_data.to_h.merge(attributes))
  end

  def clear_draft_data!
    merge_context!(draft_data: nil)
  end

  # That the citizen asked to be put back at the beginning while a contribution
  # was still in the way. Written by the inbound layer, which resets nothing on
  # that turn because throwing away what they wrote cannot be taken back, and
  # read by AbortSubmission once they have said to discard — so the reply that
  # follows the discard is the fresh start they asked for rather than a full stop.
  #
  # Nothing clears it explicitly, and nothing needs to: discard_draft!,
  # complete_draft! and start_draft! each replace the whole context, and every way
  # out of having a draft goes through one of them, so the key cannot outlive the
  # submission it was written for. What it does outlive is a change of mind — ask
  # to start over, carry on with the draft instead, abandon it an hour later, and
  # the overview comes with the discard. They did ask for it, so that is the
  # harmless direction for this to be wrong in.
  def start_over_requested?
    context["start_over_requested"] == true
  end

  def request_start_over!
    merge_context!(start_over_requested: true)
  end

  # Cleared on a revision, where the record is already persisted. Deliberately: a
  # declined photo carried over would hold for the life of the submission, so a
  # citizen who changed their mind while revising ("doch, ein Foto habe ich") would
  # have had no way to send one at all. What they said about the previous text does
  # not bind the new one.
  def reset_settled_slots!
    merge_context!(settled_slots: {})
  end

  # The pin the citizen shared through WhatsApp's own picker, parked here by the
  # inbound protocol layer because a location message carries no text and so
  # cannot be described to the assistant without losing precision. The tool that
  # writes it onto the draft reads it from here and clears it, so a pin can never
  # be attached twice or attached to a submission it did not arrive for.
  def shared_location
    context["shared_location"]
  end

  def store_shared_location!(latitude:, longitude:)
    merge_context!(shared_location: { "latitude" => latitude, "longitude" => longitude })
  end

  def clear_shared_location!
    return if context["shared_location"].blank?

    merge_context!(shared_location: nil)
  end

  # The photo the citizen sent, parked for the same reason: an image arrives as a
  # WhatsApp media id, and a media id copied by a model is one character away from
  # fetching nothing. The tool that attaches it reads it from here and clears it,
  # so one picture cannot be attached to two drafts.
  def shared_image_id
    context["shared_image_id"]
  end

  def store_shared_image!(media_id)
    merge_context!(shared_image_id: media_id)
  end

  def clear_shared_image!
    return if context["shared_image_id"].blank?

    merge_context!(shared_image_id: nil)
  end

  # The uploaded preview picture, remembered keyed by the blob it was made from,
  # so re-sends of the preview do not re-upload — and a revised picture (new blob)
  # invalidates it. One batched write.
  def preview_media_id
    context["preview_media_id"]
  end

  def preview_media_blob_id
    context["preview_media_blob_id"]
  end

  def store_preview_media!(media_id:, blob_id:)
    merge_context!(preview_media_id: media_id, preview_media_blob_id: blob_id)
  end

  # The draft as it stood in the block the citizen was last shown, digested by
  # Whatsapp::DraftPreview. Written when that block is sent and read by
  # Ai::Tools::WhatsappAiAssistant::PublishDraft, which refuses when the draft has
  # moved on since.
  #
  # An offered publish button on its own is not enough to answer "have they seen
  # this": the button is offered against a message, and the draft can be revised
  # after it without the offer going anywhere. So consent is held against the text
  # rather than against the message, and every tool that changes something the
  # block displays revokes it.
  #
  # Nothing clears any of the four keys below on completion or abandonment: the
  # whole context is replaced by retained_context, which keeps only the
  # assistant's history.
  def draft_preview_digest
    context["draft_preview_digest"]
  end

  def store_draft_preview_digest!(digest)
    merge_context!(draft_preview_digest: digest)
  end

  def revoke_draft_preview_digest!
    return if context["draft_preview_digest"].blank?

    merge_context!(draft_preview_digest: nil)
  end

  # The comment a citizen has written and not yet posted: their words and the
  # proposal they are meant for. Held here rather than as an unsaved record
  # because nothing may be written to a public page before they have seen it and
  # said yes — and because the tool that posts it must read the words from
  # somewhere the model cannot retype them in between.
  def pending_comment
    context["pending_comment"]
  end

  def store_pending_comment!(proposal_id:, text:)
    merge_context!(pending_comment: { "proposal_id" => proposal_id, "text" => text })
  end

  # Both keys in one write: the words are gone, so a digest of them is a digest of
  # nothing, and leaving it behind would let the next comment inherit a yes.
  def clear_pending_comment!
    return if context["pending_comment"].blank? && context["comment_preview_digest"].blank?

    merge_context!(pending_comment: nil, comment_preview_digest: nil)
  end

  # The comment as it stood in the block the citizen was last shown. Its own key
  # rather than the draft's, because a citizen can perfectly well have a
  # contribution half-written and be commenting on someone else's at the same
  # time.
  def comment_preview_digest
    context["comment_preview_digest"]
  end

  def store_comment_preview_digest!(digest)
    merge_context!(comment_preview_digest: digest)
  end

  # The proposal the bot last asked about, written by the tools that resolve one
  # from what the citizen called it and read back by the ones that act on it.
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

  # Whichever of the two the bot last spoke about, for the tools and the system
  # prompt.
  def active_proposal_id
    support_proposal_id || comment_proposal_id
  end

  # The irreversible actions the bot's last interactive message offered, written by
  # Whatsapp::Send for every buttons or list send. Read by the tools that must not
  # act without having asked first: an assistant is perfectly capable of deciding it
  # has already confirmed something it never mentioned, and unlinking cannot be
  # taken back once it has.
  #
  # Overwritten rather than appended — it names what the citizen is looking at now,
  # not everything they have ever been offered.
  def pending_confirmations
    Array(context["pending_confirmations"])
  end

  # Whether the bot had offered this before the citizen's message arrived — which is
  # the whole question, and not the same as whether it has been offered at all. Read
  # off the record, a tool could offer the pill and act on it inside one turn, which
  # is exactly the ceremony the offer exists to prevent. So the inbound chain holds
  # the value as it stood on arrival (#hold_offered_confirmations!) and a send later
  # in the same turn cannot talk its way into it.
  def confirmation_offered?(action)
    offered = defined?(@held_confirmations) ? @held_confirmations : pending_confirmations

    offered.include?(action.to_s)
  end

  # Called once at the top of the inbound chain, before anything can send.
  def hold_offered_confirmations!
    @held_confirmations = pending_confirmations
  end

  # That the citizen has just asked to start over, held in memory rather than
  # written down: it is true for the reply being composed and gone by the next
  # message. The inbound chain sets it and the system prompt reads it off the
  # same object, so there is nothing for a column or a context key to carry —
  # the same arrangement the held confirmations above use.
  #
  # It exists because the phase going nil is not on its own enough to stop the
  # projekt being offered again: the replayed history still has it, so the reply
  # needs telling as well as the state needs clearing.
  def note_start_over!
    @starting_over = true
  end

  def starting_over?
    @starting_over == true
  end

  # Nothing to write on the common path: most messages offer nothing irreversible,
  # and clearing a key that was never set would cost an UPDATE per reply.
  def remember_confirmations!(action_ids)
    return if action_ids.blank? && context["pending_confirmations"].blank?

    merge_context!(pending_confirmations: action_ids)
  end

  # The inbound the assistant failed to answer — the citizen's words, or the note
  # describing their tap or scan — kept so the retry pill under the "cannot answer"
  # line can put exactly that turn to the assistant again. Written by
  # Inbound::ProcessMessageService when a turn fails, read by its retry gate, and
  # cleared by the next turn that succeeds; a cancel wipes it with the rest of the
  # context. One snapshot only: a retry that fails again overwrites it with itself.
  #
  # The tap travels with the text because the note alone does not carry it: the
  # tools that must not answer a tap with the message it sat under read
  # #inbound_tap, and a retry that replayed the words without it would send the
  # card the tap was asking to move past.
  def retry_inbound
    context["retry_inbound"]
  end

  def store_retry_inbound!(text:, message_id:, tap: nil)
    merge_context!(
      retry_inbound: { "text" => text, "message_id" => message_id, "tap" => tap }.compact
    )
  end

  # No UPDATE on the common path, for the same reason as remember_confirmations!:
  # most turns succeed with nothing to clear.
  def clear_retry_inbound!
    return if context["retry_inbound"].blank?

    merge_context!(retry_inbound: nil)
  end

  # The catalog pill the citizen tapped to start the current turn, held in memory
  # rather than written down — the same arrangement as the held confirmations and
  # the start-over note above, and for the same reason: it is true for the reply
  # being composed and meaningless by the next message. The router hands the tools
  # the very object the inbound chain noted it on, so there is nothing for a
  # context key to carry.
  #
  # Persisting it was a leak: a turn that ended before the clear — AI switched off,
  # an exception out of the router — left the tap in the record, and every later
  # turn read it as though the citizen had just tapped.
  def inbound_tap
    @inbound_tap
  end

  def note_inbound_tap!(action:, param:)
    @inbound_tap = { "action" => action.to_s, "param" => param.to_s }
  end

  # The ruby_llm message history. Written and read only through
  # Whatsapp::AiAssistant::ChatState, which owns the message shape, the trimming,
  # and the replay.
  #
  # With the step machine gone this is the only thing carrying continuity between
  # two turns, which makes it considerably more load-bearing than it was.
  def stored_ai_chat
    context["ai_chat"]
  end

  def store_ai_chat!(messages)
    update!(context: context.except("ai_chain").merge("ai_chat" => messages))
  end

  # The Responses chain, for the transport that keeps the history at the provider
  # instead of here. Written and read only through
  # Whatsapp::AiAssistant::ChatChain, which owns the shape, the turn ceiling, and
  # what a chain the provider has forgotten means.
  #
  # Exclusive with the ruby_llm history above, and each writer drops the other
  # key: flipping the transport setting mid-conversation would otherwise replay a
  # history with a hole in it, or chain onto a response the other path never
  # continued.
  def stored_ai_chain
    context["ai_chain"]
  end

  def store_ai_chain!(chain)
    update!(context: context.except("ai_chat").merge("ai_chain" => chain))
  end

  def clear_ai_chain!
    update!(context: context.except("ai_chain"))
  end

  private

    # Private on purpose: every context write goes through a named accessor above,
    # so a new key cannot be introduced without declaring what it means, who reads
    # it, and when it clears.
    def merge_context!(attributes)
      update!(context: context.merge(attributes.stringify_keys))
    end

    # What outlives a submission: the assistant's history, whichever transport
    # wrote it. Everything else in the context belongs to one draft.
    def retained_context
      context.slice("ai_chat", "ai_chain")
    end
end
