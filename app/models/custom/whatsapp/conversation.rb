class Whatsapp::Conversation < ApplicationRecord
  belongs_to :whatsapp_account, class_name: "Whatsapp::Account", inverse_of: :whatsapp_conversation
  belongs_to :projekt_phase, class_name: "::ProjektPhase", optional: true

  # Every tool needs the account, and most of them only need the citizen behind
  # it. Nil until the number is linked, which is the state each caller already has
  # to answer for.
  delegate :user, :awaiting_link?, to: :whatsapp_account

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
  # that question — and it is what the /adm reach page counts and what every
  # log line already written says. It is stamped from the last tool that ran (see
  # Ai::Tools::WhatsappAiAssistant::BaseTool#diagnostic_step).
  #
  # Kept as an enum so a value nothing translates cannot be persisted, and every
  # value stays declared even where no tool stamps one any more: rows written by
  # the scripted flow still hold them, and /adm looks each one up under
  # adm.whatsapp.steps. Retiring a value would break the reading of
  # conversations that already happened.
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

  # The wider question the same reset asks: everything the citizen has written and
  # not yet sent, a comment waiting on its confirmation included. The write tools
  # keep guarding on the submission alone — a comment is not a draft and none of
  # them can act on one — but whether there is anything to discard is not a question
  # about drafts, and a citizen who has just written a comment loses it too.
  def unsaved_work?
    unsaved_submission? || pending_comment.present?
  end

  # Wider again, for the one question that is about the citizen rather than about
  # what a reset would lose: whether they are in the middle of something that
  # "Stopp" could mean leaving. A ballot is saved answer by answer, so it is not
  # unsaved work, but a citizen half-way through one is just as likely to mean the
  # vote rather than the channel. So is one who has only just been asked for their
  # words — invited to comment, asked for their idea, sent to link before a vote:
  # nothing is written yet, and the "Stopp" that answers the invitation is still
  # most likely about the step it opened.
  def step_in_progress?
    unsaved_work? || active_poll_id.present? || pending_poll_id.present? || opened_steps.any?
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

  # Whether the draft on the table carries a picture. One predicate for the tools
  # that talk about the picture and the prompt's draft line, so a request to replace
  # it is answered from the same fact wherever it comes up.
  def draft_picture_attached?
    draft_resource&.image&.attachment&.attached? == true
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
    next_context = retained_context

    if projekt_phase_id.present?
      next_context = next_context.merge(subject_change_stamp)
    end

    update!(draft_resource: nil, projekt_phase_id: nil, context: next_context)
  end

  # The same, keeping the phase: a citizen who just published usually has their
  # next idea for the same projekt.
  def complete_draft!
    update!(draft_resource: nil, context: retained_context)
  end

  # Entering a submission. The context is replaced rather than merged — a new
  # submission has settled nothing — except for the assistant's own stored
  # history, which is the conversation and outlives any one draft in it. A
  # contribution held back for later goes too: this is it being taken up, or the
  # citizen having moved on to another.
  def start_draft!(new_projekt_phase)
    next_context = retained_context.except("parked_submission")

    if new_projekt_phase&.id != projekt_phase_id
      next_context = next_context.merge(subject_change_stamp)
    end

    update!(
      draft_resource: nil,
      projekt_phase: new_projekt_phase,
      context: next_context
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
  # AbortSubmission. The contribution the citizen had only said they wanted to
  # make goes with the phase, in the same write: there is nothing of it to lose.
  def leave_projekt!
    return if projekt_phase_id.blank?

    update!(
      projekt_phase_id: nil,
      context: context.merge(subject_change_stamp, "opened_steps" => opened_steps - ["contribution"])
    )
  end

  # ── When the conversation stopped being about what it was about ─────────
  # The replayed chat does not end when a subject does. A citizen who leaves one
  # projekt and asks about another is answered from a transcript where both are
  # present and nothing says which is over, so how far back an answer reaches is
  # the model's guess — and it guessed wrong in both cases reported on 11
  # September, once quoting a location phrase from two subjects earlier and once
  # answering about a contribution in a projekt never mentioned.
  #
  # One timestamp rather than a record of what the subject was, because the only
  # question the transcript has to answer is where to draw the line: everything
  # said before this belongs to something the citizen has closed. What it was is
  # already in the lines themselves.
  #
  # Written by the four ways a subject ends — discarding a draft, entering a
  # different phase, leaving the projekt, asking to start over — and by none of
  # them when the subject did not actually change. A stamp on every draft started
  # in a projekt the conversation was already about would cut a citizen off from
  # what they had just said about their own idea.
  #
  # Retained across complete_draft! for the same reason the typing hint is: it is
  # a fact about the chat rather than about the draft being replaced. Publishing
  # and writing the next idea for the same projekt is not a change of subject.
  def subject_changed_at
    changed_at = context["subject_changed_at"]

    return if changed_at.blank?

    Time.zone.parse(changed_at)
  end

  # ── How often the bot says a question can simply be typed ───────────────
  # Every message the bot sends ends in something tappable, so the chat reads as a
  # closed menu and a citizen who wants what the buttons do not cover has no cue
  # that writing works. The cue is one sentence, and this is how much of the chat
  # has to pass before it is said again.
  #
  # Counted in the citizen's own messages, because that is what a turn is from
  # their side: a card, the list under it and the reply after it are one exchange
  # rather than three. Four of them is chosen so someone tapping their way through
  # a submission — projekt, phase, idea, photo, confirm — is not told twice inside
  # it, while someone who comes back to browse hears it again.
  TYPING_HINT_COOLDOWN_TURNS = 4

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
  # questions the citizen already answered unasked, what the draft added to their
  # words, and the drafting throttle clock. The settled slots and the additions
  # ride under their own keys because the stash is emptied at persist while the
  # photo and location questions are asked, and the draft shown, after the record
  # exists.
  #
  # Replaced rather than merged, which matters on a revision: a revision reports
  # no slots, so the slots clear. That is deliberate — carried over, a declined
  # photo would hold for the life of the submission, and a citizen who changed
  # their mind while revising would have had no way to send one at all.
  def store_generated_draft!(generated)
    merge_context!(
      draft_data: generated.except(*SETTLED_SLOT_KEYS, "additions_beyond_idea"),
      settled_slots: generated.slice(*SETTLED_SLOT_KEYS),
      additions_beyond_idea: listed_additions(generated["additions_beyond_idea"]),
      last_draft_at: Time.current.iso8601
    )
  end

  # What the draft proposes that the citizen never said, as short phrases, so the
  # question under the preview can tell them what goes in under their name. Written
  # by the drafting call through store_generated_draft! and restated by
  # revise_draft whenever the text changes; read by draft_proposal, revise_draft
  # and draft_status. Empty when the draft only rephrases them.
  def additions_beyond_idea
    Array(context["additions_beyond_idea"])
  end

  def store_additions_beyond_idea!(additions)
    merge_context!(additions_beyond_idea: listed_additions(additions))
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
  # or a comment not yet posted was still in the way. Written by the inbound
  # layer, which resets nothing on that turn because throwing away what they
  # wrote cannot be taken back, and read by AbortSubmission once they have said to
  # discard — so the reply that follows the discard is the fresh start they asked
  # for rather than a full stop.
  #
  # For a draft nothing clears it explicitly, and nothing needs to: discard_draft!,
  # complete_draft! and start_draft! each replace the whole context, and every way
  # out of having a draft goes through one of them, so the key cannot outlive the
  # submission it was written for. Posting a comment keeps the context, so
  # clear_pending_comment! takes the request with it where no draft is left to
  # hold it. What it does outlive is a change of mind — ask
  # to start over, carry on with the draft instead, abandon it an hour later, and
  # the overview comes with the discard. They did ask for it, so that is the
  # harmless direction for this to be wrong in.
  def start_over_requested?
    context["start_over_requested"] == true
  end

  def request_start_over!
    merge_context!(subject_change_stamp.merge("start_over_requested" => true))
  end

  # Going back to the beginning, from the pill and from the citizen saying so in
  # their own words alike: one implementation, so the two cannot come to mean
  # different things. The ballot goes and the phase goes; a submission or a
  # comment in progress stays until the citizen says to discard it, because
  # neither the tap nor the sentence is consent to losing what they wrote. With
  # nothing written, every invitation goes too, and the proposal a comment was
  # asked for with it: a comment asked for and not yet written used to outlive
  # the way back, and the prompt still named the proposal it was meant for.
  def begin_start_over!
    note_start_over!
    clear_ballot!
    clear_submission_wish!
    clear_parked_submission!

    if unsaved_work?
      close_step!("comment")
      request_start_over!
    else
      close_opened_steps!
      leave_projekt!
    end
  end

  # ── A submission asked for before its projekt ───────────────────────────
  # "Vorschlag erstellen" tapped with no phase open: the citizen has said they want
  # to submit something and not yet where. The assistant answers it with the open
  # projekts, and the projekt they picked from those used to be answered with its
  # whole card — nine votes and the contributions included — on which the wish they
  # had just tapped was nowhere to be seen. Held here until that card is sent, so it
  # can offer only the way to submit (Ai::Tools::WhatsappAiAssistant::SendProjektCard).
  #
  # A timestamp rather than a flag, read against the window below: a wish the
  # citizen never followed up is not one a card sent later should act on. Picking a
  # projekt from the list the tap is answered with takes a minute, so the window is
  # short. Cleared sooner by the card that uses it, by going back to the beginning,
  # and with the rest of the context by start_draft!.
  SUBMISSION_WISH_TTL = 10.minutes

  def submission_wished?
    wished_at = context["submission_wished_at"]

    return false if wished_at.blank?

    Time.zone.parse(wished_at) > SUBMISSION_WISH_TTL.ago
  end

  def record_submission_wish!
    merge_context!(submission_wished_at: Time.current.iso8601)
  end

  def clear_submission_wish!
    if context["submission_wished_at"].blank?
      return
    end

    merge_context!(submission_wished_at: nil)
  end

  # ── A contribution asked for while another is open ──────────────────────
  # A citizen part-way through a draft or a comment who asks to contribute
  # somewhere is asked first whether to discard what they have, because StartDraft
  # refuses until they say so. The idea they gave with the request used to go with
  # the answer: the discard ended on "it is gone", and the idea had to be written
  # again. Held here from the refusal, so the reply to the discard carries on with
  # it (Whatsapp::DiscardNotes), and kept through the draft they chose to finish
  # instead, so it is offered once that one is done (SystemPromptService).
  #
  # Their words as they wrote them, or none where they picked the projekt from a
  # list. It outlives the discard and the publishing, which both rebuild the
  # context (#retained_context); a new submission takes it with the rest, having
  # either taken it up or moved past it, and so does going back to the beginning.
  def parked_projekt_phase
    projekt_phase_id = context.dig("parked_submission", "projekt_phase_id")

    return if projekt_phase_id.blank?

    ::ProjektPhase.find_by(id: projekt_phase_id)
  end

  def parked_submission_text
    context.dig("parked_submission", "text")
  end

  def park_submission!(projekt_phase:, text:)
    merge_context!(
      parked_submission: {
        "projekt_phase_id" => projekt_phase.id,
        "text" => text.to_s.strip.presence
      }
    )
  end

  def clear_parked_submission!
    if context["parked_submission"].blank?
      return
    end

    merge_context!(parked_submission: nil)
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

  # That this draft's optional pin has been asked for. Asked once and never again,
  # and held as a fact the tool checks rather than left to "never ask twice", which
  # was a sentence the model was told and could talk itself past. Outside the
  # settled slots on purpose, which clear on a revision — a revised text is still
  # the same draft, and the pin was still asked for — and gone with the rest of the
  # context when the draft ends.
  def location_requested?
    context["location_requested"] == true
  end

  def record_location_requested!
    merge_context!(location_requested: true)
  end

  # That this draft's citizen has been shown both picture notices — the rights one
  # and the generated-picture one — which every way a picture reaches the draft
  # reads first. Held for the draft rather than for the last message like the
  # irreversible offers, because a photo can arrive turns after it was asked for;
  # gone with the rest of the context when the draft ends.
  def image_notices_shown?
    context["image_notices_shown"] == true
  end

  def record_image_notices_shown!
    merge_context!(image_notices_shown: true)
  end

  # A place read from the citizen's own words, held until they say it is the right
  # one: {"latitude", "longitude", "name"}. It used to be written onto the draft the
  # moment it was found, and a chat has no map — so the citizen saw "Standort" and
  # nothing else, and the contribution went online pinned in another town. Written
  # by PersistDraftService on every draft and revision (nil drops a stale one), read
  # by draft_status and set_draft_location.
  def proposed_location
    context["proposed_location"]
  end

  def store_proposed_location!(place)
    if place.present? || context["proposed_location"].present?
      merge_context!(proposed_location: place)
    end
  end

  # What the pin on the draft is called, for the block the citizen confirms: a
  # place is only confirmed by a name they recognise, and the coordinates are not
  # one. Held here because map_locations has nowhere to keep it.
  def attached_location_name
    context["attached_location_name"]
  end

  # The four keys travel together: whatever was waiting is used up, the name
  # belongs to the pin just written, and a yes given before it was a yes to a
  # different contribution.
  def record_attached_location!(name)
    merge_context!(
      shared_location: nil,
      proposed_location: nil,
      attached_location_name: name,
      draft_preview_digest: nil
    )
  end

  def record_removed_location!
    merge_context!(
      shared_location: nil,
      proposed_location: nil,
      attached_location_name: nil,
      draft_preview_digest: nil
    )
  end

  # A pin that could not be written, so that neither the shared nor the proposed
  # one can be re-attached to whatever the citizen does next.
  def clear_waiting_locations!
    merge_context!(shared_location: nil, proposed_location: nil)
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

  # The draft just shown is the version a later change starts from, so a change
  # still open from before it closes in the same write.
  def store_draft_preview_digest!(digest)
    merge_context!(draft_preview_digest: digest, **revision_closed("draft"))
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
  # nothing, and leaving it behind would let the next comment inherit a yes. The
  # invitation that asked for the words goes in the same write, because the
  # comment it opened is over, and so does a change to it still open.
  def clear_pending_comment!
    return if context["pending_comment"].blank? &&
      context["comment_preview_digest"].blank? &&
      !opened_steps.include?("comment") &&
      revision_kind != "comment"

    merge_context!(
      pending_comment: nil,
      comment_preview_digest: nil,
      opened_steps: opened_steps - ["comment"],
      **revision_closed("comment"),
      **start_over_request_closed
    )
  end

  # The invitation to comment is out and nothing has been written yet: the next
  # thing the citizen sends is their comment, and a button asking for it again
  # only repeats the message it sits under.
  def comment_invited?
    opened_steps.include?("comment") && pending_comment.blank?
  end

  # The ballot a citizen was about to be given when it turned out they had no account
  # yet. Held over the login link so the vote resumes where it stopped rather than
  # asking them to find the projekt again — the one moment they were ready to act is
  # the worst one to send them back to the beginning of.
  #
  # The poll's id rather than a question's, and re-resolved when they return: linking
  # takes as long as it takes, a poll can close while a citizen is registering, and
  # which question they are owed is read off the answers they have given rather than
  # off whichever one they happened to be looking at.
  def pending_poll_id
    context["pending_poll_id"]
  end

  def store_pending_poll!(poll_id)
    merge_context!(pending_poll_id: poll_id)
  end

  def clear_pending_poll!
    return if context["pending_poll_id"].blank?

    merge_context!(pending_poll_id: nil)
  end

  # ── The ballot in flight ────────────────────────────────────────────────
  # A ballot is asked one question at a time over as many messages as it has
  # questions, and none of the keys below is a position in it: the answers
  # already recorded are what says where the citizen has got to
  # (Polls::BallotTraversalQuery). What is written down is only what cannot be read
  # back off them.
  #
  # Which poll is being voted on, so a question asked in the middle of a ballot can
  # be answered and the ballot picked up again afterwards rather than dropped. Kept
  # until the last question is answered, the poll closes, or the citizen starts over.
  def active_poll_id
    context["active_poll_id"]
  end

  def store_active_poll!(poll_id)
    merge_context!(active_poll_id: poll_id)
  end

  # The multiple-choice question the citizen is still picking from. Its own key
  # because "has at least one answer" is what the cursor reads, and a question that
  # allows several answers is not finished by its first one — without this, a second
  # message would move past a question the citizen was half-way through choosing on.
  # Cleared by the pill that says they are done and by reaching the portal's maximum.
  def open_multiple_question_id
    context["open_multiple_question_id"]
  end

  def store_open_multiple_question!(question_id)
    merge_context!(open_multiple_question_id: question_id)
  end

  def clear_open_multiple_question!
    return if context["open_multiple_question_id"].blank?

    merge_context!(open_multiple_question_id: nil)
  end

  # The free-text question whose answer is expected as the citizen's next words. The
  # one place the bot takes a plain message as something other than a question for
  # the assistant, which is why it is written down rather than inferred: a sentence
  # typed into a chat is indistinguishable from any other until something says it
  # was asked for.
  def pending_open_question_id
    context["pending_open_question_id"]
  end

  def store_pending_open_question!(question_id)
    merge_context!(pending_open_question_id: question_id)
  end

  def clear_pending_open_question!
    return if context["pending_open_question_id"].blank?

    merge_context!(pending_open_question_id: nil)
  end

  # The map-point question whose answer is expected as the citizen's next shared
  # location. Written down for the same reason the free-text question is: a pin
  # dropped into a chat is indistinguishable from one meant for a contribution until
  # something says it was asked for, and the drafting flow asks for pins too.
  def pending_map_question_id
    context["pending_map_question_id"]
  end

  def store_pending_map_question!(question_id)
    merge_context!(pending_map_question_id: question_id)
  end

  def clear_pending_map_question!
    return if context["pending_map_question_id"].blank?

    merge_context!(pending_map_question_id: nil)
  end

  # The questions of this ballot the citizen has declined to answer. The one piece of
  # ballot state the recorded answers genuinely cannot hold: a free-text question
  # that was skipped has no answer row and never will, so without this the cursor
  # would find it unanswered and ask it again on every message for the rest of the
  # chat. Recording an empty answer instead is what the page reaps on confirmation
  # (PollsController#remove_answers_to_open_questions_with_blank_body) — a blank vote
  # row is a vote nobody cast.
  #
  # Scoped to the ballot rather than to the citizen: it goes with the other markers
  # when the ballot ends, so a poll answered again another day starts from a clean
  # slate the way the page does.
  def declined_poll_question_ids
    Array(context["declined_poll_question_ids"])
  end

  def decline_poll_question!(question_id)
    return if declined_poll_question_ids.include?(question_id)

    merge_context!(declined_poll_question_ids: declined_poll_question_ids + [question_id])
  end

  # The questions of this ballot already put to the citizen again after they turned
  # to something else. Once each: a question re-sent under every reply is a script
  # talking over the conversation — a map question sent its picker and the way past
  # it under "Welche Projekte gibt es?" for minutes on end. After that one time the
  # question stays in the state and whether to bring it back is the assistant's.
  # Scoped to the ballot like the declined questions, and cleared with them.
  def resumed_poll_question_ids
    Array(context["resumed_poll_question_ids"])
  end

  def record_resumed_poll_question!(question_id)
    return if resumed_poll_question_ids.include?(question_id)

    merge_context!(resumed_poll_question_ids: resumed_poll_question_ids + [question_id])
  end

  # All of them in one write, for the end of a ballot and for starting over.
  # Separate clears would leave a window in which the poll was gone and a question
  # of it was still expecting an answer.
  def clear_ballot!
    return if ballot_keys.all? { |key| context[key].blank? }

    merge_context!(
      active_poll_id: nil,
      open_multiple_question_id: nil,
      pending_open_question_id: nil,
      pending_map_question_id: nil,
      declined_poll_question_ids: nil,
      resumed_poll_question_ids: nil
    )
  end

  # The comment as it stood in the block the citizen was last shown. Its own key
  # rather than the draft's, because a citizen can perfectly well have a
  # contribution half-written and be commenting on someone else's at the same
  # time.
  def comment_preview_digest
    context["comment_preview_digest"]
  end

  # The same as the draft's: the comment just shown closes a change still open.
  def store_comment_preview_digest!(digest)
    merge_context!(comment_preview_digest: digest, **revision_closed("comment"))
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

  # The steps the bot has opened by asking for the citizen's words before any of
  # them have arrived: "comment" once it has invited a comment, "contribution"
  # once the citizen has said they want to contribute. Nothing is written yet, so
  # a reset loses nothing and unsaved_work? finds nothing, but step_in_progress?
  # reads this, so a "Stopp" answering the invitation is asked about rather than
  # read as leaving the channel.
  #
  # Written by StartComment and StartDraft, never by start_draft! itself: a
  # projekt card and a scanned code enter a phase too, and neither is the citizen
  # saying they want to contribute. The whole-context replacements clear both,
  # clear_pending_comment! the comment, leave_projekt! the contribution, and
  # going back to the beginning all of them, or only the comment while something
  # written waits on the citizen's answer.
  def opened_steps
    Array(context["opened_steps"])
  end

  def open_step!(kind)
    return if opened_steps.include?(kind)

    merge_context!(opened_steps: opened_steps + [kind])
  end

  def close_step!(kind)
    return if !opened_steps.include?(kind)

    merge_context!(opened_steps: opened_steps - [kind])
  end

  # ── A change on its way ─────────────────────────────────────────────────
  # The comment or the draft as the citizen last read it in its preview, kept from
  # the tap that asks to change it until the changed version is shown. The cancel
  # pill under that request used to throw the whole thing away, which is not what
  # "Änderung verwerfen" says; with this it takes back the change and nothing else
  # (Inbound::ProcessMessageService#revert_change).
  #
  # Kept only where what is on the table is still what the preview showed — past
  # that there is no version the citizen read to go back to. One level and one at a
  # time: a second change starts from the version shown after the first, and a
  # change to the draft replaces one to the comment. Closed by the next preview of
  # the same kind and by posting the comment; the whole-context replacements clear
  # it with everything else.
  def revision_open?
    context["revision_base"].present?
  end

  # "comment" or "draft", nil while no change is open.
  def revision_kind
    context["revision_base"].to_h["kind"]
  end

  def begin_comment_revision!
    return if pending_comment.blank?
    return if ::Whatsapp::CommentPreview.digest(conversation: self) != comment_preview_digest

    merge_context!(revision_base: { "kind" => "comment", "snapshot" => pending_comment })
  end

  def begin_draft_revision!
    return if draft_resource.blank?
    return if ::Whatsapp::DraftPreview.digest(conversation: self) != draft_preview_digest

    merge_context!(revision_base: { "kind" => "draft", "snapshot" => draft_snapshot })
  end

  # The version the citizen last read, back on the table. Their yes to it is not:
  # the digest goes with the change, so nothing is posted or published before the
  # preview has been sent again.
  def revert_revision!
    snapshot = context["revision_base"].to_h["snapshot"].to_h

    case revision_kind
    when "comment" then revert_comment!(snapshot)
    when "draft" then revert_draft!(snapshot)
    end
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

  # Whether the bot had already asked "only this, or all messages?" when the
  # citizen's message arrived. Asked once and only once: the next opt-out keyword
  # is honoured without a model, and stop_messages acts on a plain yes. Held on
  # arrival for the same reason as the confirmations above — the turn that asks
  # must not be able to count its own question as answered.
  def hold_stop_question!
    @held_stop_question = context["stop_question_asked"].present?
  end

  def stop_question_asked?
    return @held_stop_question if defined?(@held_stop_question)

    context["stop_question_asked"].present?
  end

  def ask_stop_question!
    merge_context!(stop_question_asked: true)
  end

  # Any message after the question answers it, so the question is settled
  # whatever that answer was: a citizen who went on with their comment and
  # typed "Stopp" an hour later is asked again rather than unsubscribed.
  def clear_stop_question!
    return if context["stop_question_asked"].blank?

    merge_context!(stop_question_asked: nil)
  end

  # The draft and the comment as they stood when the assistant's turn began, held
  # in memory like the confirmations above. What they answer is whether this turn
  # wrote or changed one, which neither the record nor the stored preview digest
  # can say on its own: a digest that differs from the preview's may be a draft
  # the citizen was never shown last week, and it is this turn's change that has
  # to be shown before anything else is sent about it.
  #
  # Called by Whatsapp::AiAssistant::RouterService before the model is asked,
  # because a turn is not always started by the inbound chain.
  def hold_preview_digests!
    @held_preview_digests = {
      draft: ::Whatsapp::DraftPreview.digest(conversation: self),
      comment: ::Whatsapp::CommentPreview.digest(conversation: self)
    }
  end

  # :draft or :comment when this turn wrote or changed one the citizen has not
  # been shown since, nil otherwise. Nil wherever nothing was held, which is every
  # caller outside a turn: without the digest from the turn's start there is no
  # telling a change from what was already there.
  def unshown_preview_kind
    return if @held_preview_digests.nil?
    return :draft if unshown_draft_change?
    return :comment if unshown_comment_change?

    nil
  end

  # The citizen message being answered, held in memory like the confirmations
  # above. Called once at the top of the inbound chain, before anything can send,
  # with the message the citizen is looking at — so a retry tap is a message of
  # its own and may be answered with the preview again.
  def hold_inbound_message_id!(message_id)
    @held_inbound_message_id = message_id
  end

  # Whether a preview of this version may go out: false where the same version
  # of the same kind has already been shown in answer to the same message. One
  # change, one preview — a second one under the same message is a second set of
  # pills for one question, and a tap under the first answers a message the bot
  # itself has replaced.
  #
  # Claimed before the send, like the preview digest, so a send that fails
  # halfway leaves a claim rather than an opening for a second preview. True
  # wherever no message is held: a turn started outside the inbound chain has
  # nothing to key it on. No row lock, because the inbound job already holds
  # the conversation's advisory lock for the whole answer
  # (Whatsapp::ProcessInboundMessageJob).
  def claim_preview!(kind:, digest:)
    return true if @held_inbound_message_id.blank? || digest.blank?

    claim = { "digest" => digest, "inbound_message_id" => @held_inbound_message_id }
    claims = context["preview_claims"].to_h

    return false if claims[kind.to_s] == claim

    merge_context!(preview_claims: claims.merge(kind.to_s => claim))

    true
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

  # That a submission went in during this turn, held the same way and for the same
  # length of time. The reply the model writes after publishing is the one message
  # that ends the exchange, so it is the one that carries the way back — and only
  # the tool that published knows the exchange ended, because the confirmation the
  # citizen reads is sent from there while the offer under it is not.
  def note_submission_completed!
    @submission_completed = true
  end

  def submission_completed?
    @submission_completed == true
  end

  # What this turn has already done, held the same way and for the same length of
  # time: the result of every tool that reported `completed: true` — a comment
  # posted, a support counted, a projekt followed — exactly as the model read it.
  # Kept as JSON so the retry snapshot can store it unchanged. Read by
  # Inbound::ProcessMessageService when the turn then fails, because a reply that
  # could not be written must not be answered as though nothing had happened — nor
  # retried as though it had not.
  #
  # The completion line the model wrote with the call sits beside the result rather
  # than in it: it is for the citizen's fallback line, and the retry hands the model
  # only what the tool answered.
  def note_completed_tool_result!(tool:, result:, completion_line: nil)
    entry = {
      "tool" => tool.to_s,
      "result" => result.as_json,
      "completion_line" => completion_line
    }.compact

    @completed_tool_results = completed_tool_results + [entry]
  end

  # A retry of a turn that had completed something starts out holding those results,
  # so what reads this turn's completed actions — its fallback line, its failure
  # report, its log — counts them too when the retry fails as well.
  def carry_completed_tool_results!(entries)
    @completed_tool_results = completed_tool_results + Array(entries)
  end

  def completed_tool_results
    @completed_tool_results || []
  end

  def completed_tool_names
    completed_tool_results.map { |entry| entry["tool"] }
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
  # Where the failed turn had already completed something, the snapshot holds a note
  # saying so instead of the inbound, and the completed tool results beside it, so
  # that a retry which fails as well can still tell the citizen it went through.
  def retry_inbound
    context["retry_inbound"]
  end

  # Whether tapping "try again" would actually replay something. The snapshot is
  # stored only by a transient failure and cleared by the next turn that succeeds,
  # so without it the tap reaches the assistant as a bare note about a button press
  # and the citizen is answered by improvisation rather than by their own message.
  #
  # Reads the text rather than the key, the same way the tap handler does: an
  # entry whose text went missing replays nothing either.
  def replayable_turn?
    retry_inbound.to_h["text"].present?
  end

  def store_retry_inbound!(text:, message_id:, citizen_words:, completed_tool_results: [])
    merge_context!(
      retry_inbound: {
        "text" => text,
        "message_id" => message_id,
        "citizen_words" => citizen_words,
        "completed_tool_results" => completed_tool_results.presence
      }.compact
    )
  end

  # No UPDATE on the common path, for the same reason as remember_confirmations!:
  # most turns succeed with nothing to clear.
  def clear_retry_inbound!
    return if context["retry_inbound"].blank?

    merge_context!(retry_inbound: nil)
  end

  # The id of the citizen's newest message at the moment the bot last said a
  # question can simply be typed. An id rather than a tally or a timestamp: it is
  # monotonic, it is already in the database wherever the hint is sent, and how many
  # turns have passed since is then one indexed count — where a stored tally would
  # cost an UPDATE on every single message to keep.
  #
  # Zero when the hint was said before the citizen had written anything, which a
  # conversation the bot opened itself can be. Zero rather than nil on purpose: nil
  # is "never said" and would offer the hint again on the next message.
  #
  # Written by the tools whose message presents a projekt or a phase and read by the
  # system prompt, which turns it into the one line telling the model whether the
  # hint is due. Kept by retained_context, because a hint already given must not be
  # said again merely because a submission started.
  def typing_hint_at_message_id
    context["typing_hint_at_message_id"]
  end

  def stamp_typing_hint!
    merge_context!(typing_hint_at_message_id: inbound_messages.maximum(:id).to_i)
  end

  # Never said, or enough of the citizen's own messages have gone by since it was.
  # Deliberately not memoized: a tool stamps it part-way through a turn and the next
  # tool in the same turn has to see that it is no longer due.
  def typing_hint_due?
    stamped = typing_hint_at_message_id

    return true if stamped.blank?

    inbound_messages.where(id: (stamped.to_i + 1)..).count >= TYPING_HINT_COOLDOWN_TURNS
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

    # Every message the citizen has sent on this number, which is what the typing
    # hint's cooldown is measured in. Counted rather than loaded, and narrowed by
    # the account's own index.
    def inbound_messages
      whatsapp_account.whatsapp_messages.inbound
    end

    # Private on purpose: every context write goes through a named accessor above,
    # so a new key cannot be introduced without declaring what it means, who reads
    # it, and when it clears.
    def merge_context!(attributes)
      update!(context: context.merge(attributes.stringify_keys))
    end

    def listed_additions(additions)
      Array(additions).map { |addition| addition.to_s.squish }.compact_blank
    end

    # The change of this kind closed in the same write as whatever ends it, and
    # nothing where none of this kind is open.
    def revision_closed(kind)
      return {} if revision_kind != kind

      { revision_base: nil }
    end

    # A request to start over that only the comment was holding up ends with it;
    # one a draft still holds up stays for the draft.
    def start_over_request_closed
      return {} if !start_over_requested?
      return {} if unsaved_submission?

      { start_over_requested: nil }
    end

    # Every step opened by asking for the citizen's words, and the proposal the
    # comment one was asked about. Nothing is written yet, so nothing is lost.
    def close_opened_steps!
      return if opened_steps.empty? && comment_proposal_id.blank?

      merge_context!(opened_steps: [], comment_proposal_id: nil)
    end

    # What revise_draft changes: the record's title and text, the assessment that is
    # cleared with the text, and the two keys restated beside them.
    def draft_snapshot
      {
        "title" => draft_resource.title,
        "description" => draft_resource.description,
        "ai_evaluation_result" => draft_resource.ai_evaluation_result,
        "additions_beyond_idea" => additions_beyond_idea,
        "settled_slots" => settled_slots
      }
    end

    def revert_comment!(snapshot)
      merge_context!(pending_comment: snapshot, comment_preview_digest: nil, revision_base: nil)
    end

    # Saved without a second look from the model: the snapshot is a version the
    # record already held and the citizen already read.
    def revert_draft!(snapshot)
      if draft_resource.present?
        draft_resource.title = snapshot["title"]
        draft_resource.description = snapshot["description"]
        draft_resource.ai_evaluation_result = snapshot["ai_evaluation_result"]
        draft_resource.save!
      end

      merge_context!(
        additions_beyond_idea: Array(snapshot["additions_beyond_idea"]),
        settled_slots: snapshot["settled_slots"].to_h,
        draft_preview_digest: nil,
        revision_base: nil
      )
    end

    def unshown_draft_change?
      unshown_change?(
        ::Whatsapp::DraftPreview.digest(conversation: self),
        held: @held_preview_digests[:draft],
        shown: draft_preview_digest
      )
    end

    def unshown_comment_change?
      unshown_change?(
        ::Whatsapp::CommentPreview.digest(conversation: self),
        held: @held_preview_digests[:comment],
        shown: comment_preview_digest
      )
    end

    def unshown_change?(current, held:, shown:)
      current.present? && current != held && current != shown
    end

    def ballot_keys
      %w[
        active_poll_id open_multiple_question_id pending_open_question_id
        pending_map_question_id declined_poll_question_ids resumed_poll_question_ids
      ]
    end

    # What outlives a submission: the assistant's history, whichever transport
    # wrote it, and when the bot last said a question can simply be typed.
    # Everything else in the context belongs to one draft.
    #
    # The typing hint is here because it is a fact about the whole chat rather than
    # about a draft in it — dropped with the rest, a citizen would be told again the
    # moment they started a submission, which is the one point in the conversation
    # where they are least in need of it.
    #
    # A contribution held back for later belongs to the next draft rather than to
    # this one, so it outlives this one's end (#parked_projekt_phase).
    def retained_context
      context.slice(
        "ai_chat", "ai_chain", "typing_hint_at_message_id", "subject_changed_at",
        "parked_submission"
      )
    end

    # String-keyed because two of its three callers merge it into a context being
    # replaced wholesale rather than through merge_context!, and those never see
    # the symbol keys stringified.
    def subject_change_stamp
      { "subject_changed_at" => Time.current.iso8601 }
    end
end
