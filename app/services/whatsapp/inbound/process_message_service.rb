class Whatsapp::Inbound::ProcessMessageService < ApplicationService
  # The protocol layer, and nothing else. It used to be a nine-gate chain that
  # decided what a message meant and which of forty flows answered it; the assistant
  # owns that now, so what is left here is the handful of things that must be true
  # before a model is asked, or that must work when one cannot be.
  #
  # THE GATE CHAIN — ordering is the contract:
  #
  # - The typed STOP and START words are read before any model is asked. An outage
  #   that keeps broadcasting to a number that asked us to stop is the failure
  #   nothing may allow, so leaving the channel cannot depend on a provider being
  #   reachable. That is also why the keyword list is the one piece of reading left
  #   in Ruby: it is deterministic on purpose, not for want of a better reader.
  # - An unsubscribed number reaches no model and gets nothing about the portal
  #   answered: being conversed with is the one thing unsubscribing asked us not to
  #   do. It used to reach a classifier — a whole model call whose only question was
  #   whether the message was an opt-in, which the keyword above now answers. What
  #   it does get, at most once a week, is the one line naming the word that brings
  #   it back, because the keyword that took it out of the channel is also the
  #   ordinary word for abandoning a draft.
  # - A voice note is transcribed just ahead of the keyword gate, the first text
  #   consumer. The "could not read it" reply goes out there, but the chain runs on.
  # - Cancelling is read before anything else can act on the message, for the same
  #   reason as the stop keyword: leaving a half-written submission must not depend
  #   on a provider being reachable. A text-less voice note halts only after that
  #   gate, because a tap is never audio.
  # - The two pills that mean "back to the beginning" are read here for that reason
  #   as well, and theirs is the one gate that does not halt: clearing the phase is
  #   only half of what the citizen asked for, and the other half is the reply,
  #   which is the overview of what applies now and so the assistant's to write.
  # - The projekt card's phase pills are answered here rather than described to the
  #   assistant, and theirs is the one gate that is about the reply rather than about
  #   surviving without a model: the card names an action, so tapping it has to be that
  #   action and not a question about it. A pill that can no longer be honoured falls
  #   through to the assistant, which is what says why. A vote cast on one of a poll's
  #   answer pills is the same gate for the same reason, one below it.
  # - The AI disclosure precedes any reply the assistant could make. It is a legal
  #   declaration rather than a sentence the bot chooses, which is why it is here and
  #   on the locale copy.
  # - Everything else is the assistant's, and the recovery line is what happens when
  #   the assistant does not answer.
  OPT_OUT_KEYWORDS = ["stop", "stopp", "abmelden", "unsubscribe"].freeze

  # The way back in for a number that left. Deterministic for the same reason
  # leaving is: an unsubscribed number reaches no model, so the only thing that can
  # read this is Ruby.
  OPT_IN_KEYWORDS = ["start", "anmelden", "subscribe"].freeze

  # How many of a phase's contributions the reply names in words. Fewer than the nine
  # a list holds, and deliberately: each one is named over two lines with its own
  # address, and past five of those the body outgrows the 1024 characters an
  # interactive message allows — which Whatsapp::Send does not truncate but splits,
  # sending everything but the last chunk as a separate plain message and leaving the
  # list attached to whatever the sentence above it had become.
  MAX_NAMED_CONTRIBUTIONS = 5

  # Keyed by the phase's own type name, the way the projekt card's buttons are:
  # what a phase holds is named differently for a milestone than for a proposal, and
  # a register kept per type is the only one that cannot describe next month's events
  # as something that has already come in.
  CONTRIBUTIONS_INTRO_SCOPE = "whatsapp.bot.phase.contributions_intro".freeze

  def initialize(whatsapp_message:, raw_message: {})
    @whatsapp_message = whatsapp_message
    @raw_message = raw_message || {}
  end

  def call
    return if !::Whatsapp.enabled?

    conversation.update!(last_inbound_at: latest_inbound_at)

    # Before anything can send: the tools that must not act on an irreversible offer
    # they made themselves read this rather than the record.
    conversation.hold_offered_confirmations!

    # Every message is acknowledged, tapped ones included: a tap that produces no
    # bubble reads as a tap that did not arrive, and the citizen taps again.
    ::Whatsapp::Send.typing(message_id: reading.message_id)

    announce_unreadable_voice_note

    return if handle_channel_keywords
    return offer_way_back_in if account.opt_out_at.present?

    disclose_ai

    return if handle_cancel_tap
    return if handle_retry_tap
    return if handle_phase_tap
    return if handle_contribution_tap
    return if handle_poll_answer_tap
    return if handle_poll_weight_tap
    return if handle_poll_done_tap
    return if handle_poll_skip_tap
    return if handle_poll_location
    return if handle_open_answer_text

    apply_start_over_tap

    return if reading.tapped_reply_id.blank? && reading.unreadable_voice_note?

    entry = capture_entry_token

    park_media

    inbound_note = tap_note || entry_note(entry) || reading.text.presence || media_note

    # Read before the turn, because the turn is what may end the ballot: a citizen
    # who asks to submit something instead has left it, and start_draft! replaces the
    # whole context with the assistant's own history, markers included.
    ballot_in_flight = conversation.active_poll_id

    answer(inbound_note, inbound_message_id: reading.message_id)

    resume_ballot(ballot_in_flight)
  end

  private

    # The one place the assistant is asked anything, whether what reaches it is the
    # citizen's own words, a note saying which button they tapped, or a note saying
    # which QR code they scanned. All three are the same thing to a model reading one
    # conversation: something happened, and a reply is owed.
    #
    # The message id travels separately because a retry puts the failed inbound back
    # under its own id, not under the tap that asked for it.
    #
    # The bubble does not follow it. Whatever is being answered, the citizen is
    # watching the message they have just sent, and that is the only one WhatsApp
    # will hang a typing indicator on — so the turn re-arms on the live inbound
    # while the assistant is asked about the snapshotted one.
    def answer(inbound_text, inbound_message_id:)
      return send_unavailable_line if !::Ai::Settings.ai_available?

      result = ::Whatsapp::AiAssistant::RouterService.call(
        conversation: conversation,
        inbound_text: inbound_text,
        inbound_message_id: inbound_message_id,
        typing_message_id: reading.message_id,
        previous_inbound_at: previous_inbound_at
      )

      return conversation.clear_retry_inbound! if result.success?

      # The note describing a tap is snapshotted as the text it is: what the retry
      # replays is the sentence the assistant was given, which already says which
      # button was pressed.
      conversation.store_retry_inbound!(text: inbound_text, message_id: inbound_message_id)

      send_retryable_unavailable_line
    end

    # The whole deterministic surface left, and it is one sentence with a way out.
    # It is reached for a provider that cannot be reached, a turn that timed out, a
    # blank reply, a tool loop that ran away, and a tenant with AI switched off —
    # which is a change in the deployment story rather than in this method: before,
    # nine services degraded to fixed copy and a keyless tenant had a working bot.
    #
    # Only the transient failures carry the retry pill, and only their sentence points
    # at it. A tenant with AI switched off cannot be helped by asking again, and a
    # button that never works is the dead end the pill exists to remove.
    def send_unavailable_line
      send_unavailable_line_offering(
        body: I18n.t("whatsapp.bot.assistant_unavailable"), actions: [:cancel]
      )
    end

    def send_retryable_unavailable_line
      send_unavailable_line_offering(
        body: I18n.t("whatsapp.bot.assistant_unavailable_retryable"), actions: %i[retry cancel]
      )
    end

    def send_unavailable_line_offering(body:, actions:)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :assistant_unavailable, conversation: conversation
      )

      ::Whatsapp::Send.recovery_without_assistant(
        conversation: conversation, body: body, actions: actions
      )
    end

    # A citizen asked question two of five and wrote something else instead. The
    # something else is answered first — it is what they asked, and a bot that
    # ignores a question because a ballot is open is a form, not a chat — and then
    # the question is put again, because the ballot is the thing they were doing.
    #
    # Nothing is ever dropped either way: every answer is recorded as it is given, so
    # a ballot that is abandoned here keeps what was already said.
    #
    # Held back where the turn moved the conversation somewhere else. A citizen who
    # asked to submit a contribution is now drafting one, and re-asking a poll
    # question on top of that is the bot talking over itself.
    def resume_ballot(poll_id)
      return if poll_id.blank?
      return if conversation.reload.active_poll_id != poll_id
      return if conversation.unsaved_submission?

      poll = ::Poll.find_by(id: poll_id)

      return if poll.blank?

      ::Whatsapp::Polls::AdvanceBallotService.call(conversation: conversation, poll: poll)
    end

    def reading
      @reading ||= ::Whatsapp::Inbound::MessageReading.new(
        whatsapp_message: @whatsapp_message, raw_message: @raw_message
      )
    end

    # The transcription-failure reply's position is load-bearing: whoever reads text
    # first decides who receives it, and the keyword gate below is the first text
    # consumer. The reply goes out here, but the chain runs on.
    def announce_unreadable_voice_note
      return if !reading.unreadable_voice_note?

      ::Whatsapp::Send.recovery(
        conversation: conversation,
        body: I18n.t("whatsapp.bot.transcription_failed"),
        actions: [:cancel]
      )
    end

    # Never for a tapped pill, whose label the citizen did not write: a button reading
    # "Start" is not the opt-in keyword.
    def handle_channel_keywords
      return false if reading.tapped_reply_id.present?
      return handle_opt_out if OPT_OUT_KEYWORDS.include?(normalized_text)
      return handle_opt_in if OPT_IN_KEYWORDS.include?(normalized_text)

      false
    end

    # The catalog uses one word for two things: "Stop" abandons what is in progress,
    # and "STOP" ends all messages for good. Decided here rather than inside either
    # service — getting it wrong means a citizen who wanted to cancel is silently
    # unsubscribed instead.
    def handle_opt_out
      if conversation.unsaved_submission?
        conversation.discard_draft!

        send_cancelled_line
      else
        ::Whatsapp::Accounts::MessageDeliveryService.disable(conversation: conversation)
      end

      true
    end

    def handle_opt_in
      return false if account.opt_out_at.blank?

      ::Whatsapp::Accounts::MessageDeliveryService.enable(conversation: conversation)

      true
    end

    # ── An unsubscribed number that keeps writing ───────────────────────────
    # Being conversed with is the one thing unsubscribing asked us not to do, so
    # this stays outside the assistant's reach entirely — no model is asked and
    # nothing about the portal is answered. What it is no longer is silence.
    #
    # "Stopp" is the ordinary German word for stop-what-you-are-doing, so a share
    # of the numbers here meant to abandon a half-written contribution rather
    # than to leave the channel; every message they wrote afterwards was dropped
    # without a word, and the way back was a keyword nobody had been told.
    #
    # Throttled off the last thing the bot said to this number rather than off a
    # column of its own, and the message log answers exactly this question for
    # exactly this case: a broadcast skips an opted-out number and the assistant
    # never reaches one, so the only thing that writes to one is this line.
    OPT_OUT_REMINDER_INTERVAL = 7.days

    def offer_way_back_in
      return if !way_back_in_due?

      send_bot_line(
        I18n.t(
          "whatsapp.bot.compliance.opted_out_reminder",
          keyword: OPT_IN_KEYWORDS.first.upcase
        )
      )
    end

    def way_back_in_due?
      last_spoken_at = account.whatsapp_messages.outbound.maximum(:created_at)

      last_spoken_at.blank? || last_spoken_at < OPT_OUT_REMINDER_INTERVAL.ago
    end

    # Once per number rather than once per 24-hour window: a regular who reads it
    # every day stops reading it at all. Sending it dismisses the typing bubble asked
    # for above, and everything below still has its wait ahead of it.
    def disclose_ai
      return if account.ai_disclosed?

      send_bot_line(
        I18n.t(
          "whatsapp.bot.compliance.disclosure", portal_name: ::Whatsapp::PortalLinks.portal_name
        )
      )
      account.mark_ai_disclosed!

      ::Whatsapp::Send.typing(message_id: reading.message_id)
    end

    # ── Turning a tap into something to read ────────────────────────────────
    # A tapped button says nothing this service can pass on as it stands, so it
    # becomes one line of fact beside the two below it. What it deliberately does not
    # become is an instruction: the assistant wrote that button's label one message
    # ago and the tool descriptions say what each action is for, so a second account
    # of either here would be a copy that drifts from both.
    #
    # The id is the part that has to travel. WhatsApp returns the button's *id*, and
    # since the assistant writes its own labels the label is no longer a key — a
    # sentiment pill labelled "Finde ich gut" names id 9 and nothing else in the
    # exchange does.
    def tap_note
      tapped_id = reading.tapped_reply_id

      return if tapped_id.blank?

      return start_over_note if start_over_tap?

      recovery = ::Whatsapp::Send.recovery_action_from(tapped_id)

      return tapped_line(action: recovery) if recovery.present?

      flow_action = ::Whatsapp::FlowActions.parse(tapped_id)

      return unhandled_tap_note(tapped_id) if flow_action.blank?

      record_tap(flow_action[:action], flow_action[:param])
      settle_slot_for(flow_action[:action])

      support_toggle_note(action: flow_action[:action], param: flow_action[:param]) ||
        tapped_line(action: flow_action[:action], param: flow_action[:param])
    end

    # The label the citizen actually read, taken from the webhook rather than from
    # anything remembered here: WhatsApp sends the title back beside the id.
    def tapped_line(action:, param: nil)
      label = reading.tapped_reply_title.to_s.squish
      named = label.present? ? " \"#{label}\"" : ""
      identified = param.present? ? ", id #{param}" : ""

      "The citizen tapped the button#{named} (action #{action}#{identified})."
    end

    # ── A support given or taken back on the tap itself ─────────────────────
    # The one write left on this side of the assistant, and it is here for the same
    # reason cancelling is: what it acts on arrives from WhatsApp rather than from a
    # model. That is also what pays for the ceremony a support used to carry. Asked
    # to support proposal 4821, a tool had only the model's word that 4821 was ever
    # put in front of the citizen, so the offer had to be recorded in one turn and
    # the act allowed only in the next — two taps for one support. A tapped id needs
    # none of that: it is the id of a button the citizen was looking at.
    #
    # Which way it goes is read here rather than carried in the id. One pill toggles,
    # and the citizen's vote as it stands when the tap arrives is the only thing that
    # can say whether tapping gives a support or takes one back. The label was built
    # from the same reading a message earlier, which is what keeps the two in step —
    # and where they disagree, because the vote moved on the projekt page in between,
    # it is this reading that is right.
    #
    # The retired `support` id comes through here too. Every support pill the bot has
    # ever sent is still sitting in a chat history and still tappable, and it only
    # ever meant the one thing.
    SUPPORT_TOGGLE_ACTIONS = %i[support_toggle support].freeze

    def support_toggle_note(action:, param:)
      return if !SUPPORT_TOGGLE_ACTIONS.include?(action)
      return if param.blank?
      return NOT_LINKED_NOTE if account.user.blank?

      proposal = ::Proposal.not_retired.find_by(id: param.to_i)

      return SUPPORT_GONE_NOTE if proposal.blank?
      return withdrawn_support_note(proposal) if proposal.voted_up_by?(account.user)

      registered_support_note(proposal)
    end

    def registered_support_note(proposal)
      supports = ::Whatsapp::Contributions::RegisterSupportService.call(
        proposal_id: proposal.id, user: account.user
      )

      return support_refusal_note(supports, proposal) if supports.is_a?(Symbol)

      ::Whatsapp::Send.message_block(
        account: account,
        block: ::Whatsapp::SupportRecap.registered_block(
          account: account, proposal: proposal, supports: supports
        )
      )

      REGISTERED_NOTE
    end

    def withdrawn_support_note(proposal)
      supports = ::Whatsapp::Contributions::WithdrawSupportService.call(
        proposal_id: proposal.id, user: account.user
      )

      return support_refusal_note(supports, proposal) if supports.is_a?(Symbol)

      ::Whatsapp::Send.message_block(
        account: account,
        block: ::Whatsapp::SupportRecap.withdrawn_block(
          account: account, proposal: proposal, supports: supports
        )
      )

      WITHDRAWN_NOTE
    end

    # The rule underneath rather than the sentence, the same way a tool reports a
    # refusal: the sentence is the assistant's to write for the question they
    # actually asked, in their language. Nothing has been sent on any of these paths,
    # so unlike the two notes above there is nothing to tell it not to repeat.
    #
    # The two "already" answers are races rather than mistakes — the vote read a
    # moment ago moved on the projekt page or in another chat before the write
    # landed. Both are the state the citizen wanted, so neither is reported as a
    # failure.
    def support_refusal_note(reason, proposal)
      return ALREADY_SUPPORTED_NOTE if reason == :already_supported
      return NOT_SUPPORTED_NOTE if reason == :not_supported
      return WRITE_FAILED_NOTE if reason == :not_registered || reason == :not_withdrawn
      return SUPPORT_GONE_NOTE if reason == :gone
      return NOT_LINKED_NOTE if reason == :not_linked

      rule = ::Whatsapp::ParticipationRules.explain(
        reason: reason, projekt_phase: proposal.projekt_phase
      )

      "The citizen tapped the support button and their support could not be registered, so " \
        "nothing changed. The reason: #{rule}"
    end

    REGISTERED_NOTE = "The citizen tapped the support button and their support is registered. " \
                      "The contribution, its new count and its address have already been sent " \
                      "to them, so repeat none of it: say in one line that it is registered. Do " \
                      "not invite them to support anything else, and do not say it is final or " \
                      "cannot be taken back — the same button now takes it back.".freeze

    WITHDRAWN_NOTE = "The citizen tapped the support button on a contribution they already " \
                     "supported, so the support has been taken back. The contribution, the " \
                     "count as it now stands and its address have already been sent to them, so " \
                     "repeat none of it: say in one line that it is withdrawn. Do not ask why " \
                     "and do not talk them back into it — the same button supports it again.".freeze

    ALREADY_SUPPORTED_NOTE = "They already support that contribution, and nothing changed. Say " \
                             "so plainly rather than as a failure.".freeze

    NOT_SUPPORTED_NOTE = "They do not support that contribution, so there was nothing to take " \
                         "back and nothing changed. Say so plainly rather than as a failure.".freeze

    WRITE_FAILED_NOTE = "The tap did not take: nothing was written and the count is unchanged. " \
                        "Tell the citizen it did not go through and that the button is still " \
                        "there to try again. Do not say it worked.".freeze

    SUPPORT_GONE_NOTE = "The contribution behind that button no longer has a public page — it " \
                        "may have been retired since it was mentioned. Tell the citizen so; " \
                        "nothing was changed.".freeze

    NOT_LINKED_NOTE = "This number is not linked to an account, so a support cannot be " \
                      "registered or taken back. Tell the citizen an account is needed and call " \
                      "send_login_link when they want one.".freeze

    # ── Back to the beginning ───────────────────────────────────────────────
    # The pill that sits on every interactive message the bot sends, and the one
    # offered under every cancellation and every line saying the assistant could
    # not be reached. Both mean the same thing and so are read the same way: it
    # used to be neither, and a tap on either left the conversation exactly where
    # it was — the phase still active, the state block still naming the projekt,
    # and so a reply that said "back at the beginning" and offered a contribution
    # to that projekt in the next sentence.
    #
    # The phase is all it clears. Everything else in the context belongs to one
    # submission, and this pill is on every message: a citizen who taps it must
    # not thereby lose text they have written. Where there is something to lose,
    # the reset waits for them to say so and AbortSubmission does it — one
    # implementation of the discard, and the tap alone is not consent to it.
    #
    # What is written down there is the request itself, because the confirmation
    # arrives in a later turn than the asking: without it the discard would end
    # the exchange on "it is gone", which is not what they asked for.
    def apply_start_over_tap
      return if !start_over_tap?

      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :start_over,
        conversation: conversation,
        unsaved: conversation.unsaved_submission?
      )

      conversation.note_start_over!
      conversation.clear_ballot!

      if conversation.unsaved_submission?
        conversation.request_start_over!
      else
        conversation.leave_projekt!
      end
    end

    # One id from each namespace, which is why both are read here: the start-over pill
    # is built from the catalog and keeps its catalog id, because every one already
    # sent is still sitting in a chat history and still tappable.
    START_OVER_ACTIONS = %i[main_menu help].freeze

    def start_over_tap?
      tapped_id = reading.tapped_reply_id

      return false if tapped_id.blank?

      action = ::Whatsapp::Send.recovery_action_from(tapped_id) ||
        ::Whatsapp::FlowActions.parse(tapped_id)&.fetch(:action)

      START_OVER_ACTIONS.include?(action)
    end

    # Said rather than left to the cleared state, because the state is not the only
    # thing the model reads: the stored history is replayed every turn and still has
    # the projekt in it, so a nil phase on its own is one line of evidence against
    # ten. This note is the newest message in the turn, which is the only place a
    # correction outweighs what came before it.
    def start_over_note
      return START_OVER_WITH_DRAFT_NOTE if conversation.unsaved_submission?

      START_OVER_NOTE
    end

    START_OVER_NOTE = "The citizen asked to go back to the start. No projekt and no phase " \
                      "is selected any more, and nothing said earlier in this conversation " \
                      "about one carries into what follows: do not offer that projekt, its " \
                      "phases or a contribution to it unless they name it again themselves. " \
                      "Send them what applies right now — what is open to take part in, what " \
                      "they have already done, what there is to read.".freeze

    START_OVER_WITH_DRAFT_NOTE = "The citizen asked to go back to the start while part-way " \
                                 "through a contribution. Nothing has been discarded and the " \
                                 "projekt is still selected, because throwing away what they " \
                                 "wrote cannot be taken back. Say in one line what is " \
                                 "unsaved, and ask whether to discard it or carry on with " \
                                 "it. Call abort_submission only if they say to discard.".freeze

    # Cancelling is the one tap that does its own work, and its gate is up in the
    # chain with the stop keyword for the same reason: abandoning a submission must
    # not depend on a provider being reachable. Recovery ids are read before catalog
    # ones — the two namespaces are built by different modules from different
    # prefixes, so this can never swallow a catalog pill.
    def handle_cancel_tap
      return false if ::Whatsapp::Send.recovery_action_from(reading.tapped_reply_id) != :cancel

      record_tap(:cancel, nil)

      conversation.discard_draft!

      send_cancelled_line

      true
    end

    # The retry pill under the "cannot answer" line. It repeats the turn that failed
    # rather than describing the tap to the assistant: the snapshot is the inbound
    # exactly as it was put to the model the first time, so whatever the citizen had
    # entered is still what is being answered. Sitting above the assistant like the
    # cancel gate, it answers with the same line again when the retry fails too —
    # `answer` re-snapshots on failure, so the pill stays on.
    #
    # This id is not the one the link-outcome message offers, which has `link_retry`
    # of its own. The two pills read the same to a citizen and mean different things
    # — replay the turn, and follow the login link once more — so while they shared
    # an id, tapping the link one with any snapshot left over answered it with
    # whatever turn the assistant had last failed to write.
    #
    # Without a snapshot the tap falls through to the note path, where the assistant
    # is the one that knows what "again" means.
    # The projekt card's own pills, and the one gate here that exists to answer rather
    # than to survive an outage. The card names each open phase's action — vote, fill
    # in the form, report a defect, see what is already there — and the point of
    # naming it is that tapping it does that thing. Describing the tap to the assistant
    # instead would put a model between the citizen and the action they just chose,
    # which is the selection step the card was rebuilt to remove.
    #
    # Only the actions with nowhere else to go arrive here. A phase the bot can take a
    # submission into carries `idea_start`, which enters the drafting flow through the
    # assistant like it always has.
    #
    # Falls through rather than answering wherever the pill can no longer be honoured —
    # the phase closed, the projekt was deactivated, the page unpublished since the card
    # was sent. The assistant is what says so, and it says it better than a fixed line.
    def handle_phase_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)
      action = flow_action&.fetch(:action)

      return false if !::Whatsapp::FlowActions.direct_phase?(action)

      projekt_phase = tapped_phase(flow_action[:param])

      return false if projekt_phase.blank?

      record_tap(action, flow_action[:param])

      return open_phase(projekt_phase) if action == :phase_open

      open_phase_contributions(projekt_phase)
    end

    # Re-resolved and re-checked on arrival, never trusted from the id: a pill sits in
    # a chat history for as long as the chat does, and what it points at is only what
    # it pointed at when it was sent.
    def tapped_phase(param)
      ::Whatsapp::EligiblePhasesQuery.reachable(param)
    end

    # A voting phase is asked first whether its poll is one the chat can carry to the
    # end, because for that shape of poll the action the button names is a vote and
    # tapping it should be voting. Every other phase, and every poll the chat cannot
    # finish, gets the link — which is the fallback the whole voting flow is built
    # around rather than an afterthought.
    #
    # A voting phase's link is the ballot, not the projekt page: the citizen has
    # already said which phase they want by tapping its pill, and the page they used
    # to land on answered that with a list containing the one poll it holds. The page
    # is still what everything else opens, and what a voting phase falls back to when
    # its poll has not been published.
    def open_phase(projekt_phase)
      return true if ::Whatsapp::Polls::OfferBallotService.call(
        conversation: conversation, projekt_phase: projekt_phase
      )

      send_line_with_link(
        line: I18n.t("whatsapp.bot.phase.open", phase: projekt_phase.title),
        url: ::Whatsapp::ProjektLink.ballot_url(projekt_phase) ||
          ::Whatsapp::ProjektLink.phase_url(projekt_phase)
      )
    end

    # A tap on one of a poll's answer pills. Its parameter is an answer id rather than
    # a phase id, which is why it is not the gate above: everything else about it is
    # the same rule — resolved on arrival, re-checked against the poll as it stands
    # now, and handed to the assistant when it can no longer be honoured.
    def handle_poll_answer_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)

      return false if flow_action&.fetch(:action) != :poll_answer

      question_answer = ::Poll::Question::Answer.find_by(id: flow_action[:param].to_i)

      return false if question_answer.blank?

      record_tap(:poll_answer, flow_action[:param])

      ::Whatsapp::Polls::RecordAnswerService.call(
        conversation: conversation, question_answer: question_answer
      )
    end

    # "I have picked everything I want" on a multiple-choice question. It settles the
    # question rather than answering it — whatever was chosen is already recorded,
    # each choice as it was made — so all it does is let the ballot move on.
    #
    # Honoured only for the question the bot is actually in the middle of asking. The
    # pill sits in the chat history like every other, and tapped a day later it would
    # otherwise reopen a ballot that has been finished and closed off.
    def handle_poll_done_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)

      return false if flow_action&.fetch(:action) != :poll_done
      return false if conversation.open_multiple_question_id.to_i != flow_action[:param].to_i

      record_tap(:poll_done, flow_action[:param])

      conversation.clear_open_multiple_question!

      advance_ballot
    end

    # A tap on one of the numbers offered beside one choice of a weighted question.
    # Its parameter names the option and the weight together, and it is the one pill
    # that carries two things: the label is a digit, which says nothing at all about
    # what it is a weight for.
    def handle_poll_weight_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)

      return false if flow_action&.fetch(:action) != :poll_weight

      answer_id, weight = flow_action[:param].to_s.split("_")
      question_answer = ::Poll::Question::Answer.find_by(id: answer_id.to_i)

      return false if question_answer.blank? || weight.blank?

      record_tap(:poll_weight, flow_action[:param])

      ::Whatsapp::Polls::RecordWeightedAnswerService.call(
        conversation: conversation, question_answer: question_answer, weight: weight.to_i
      )
    end

    # "I would rather not answer this one." Nothing is recorded and anything recorded
    # before is removed, which is what the page does with an open answer left empty.
    #
    # The same pill ends a map-point question, which has the same problem and one
    # more: WhatsApp's location picker carries no buttons at all, so the way past the
    # question travels in a message of its own. Which of the two questions is being
    # declined is decided by the marker that names it, never by the pill — both sit in
    # the chat history forever and either marker may be the one holding.
    def handle_poll_skip_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)

      return false if flow_action&.fetch(:action) != :poll_skip

      question_id = flow_action[:param].to_i

      if conversation.pending_open_question_id.to_i == question_id
        record_tap(:poll_skip, flow_action[:param])

        return ::Whatsapp::Polls::RecordOpenAnswerService.skip(conversation: conversation)
      end

      return false if conversation.pending_map_question_id.to_i != question_id

      record_tap(:poll_skip, flow_action[:param])

      ::Whatsapp::Polls::RecordMapPointService.skip(conversation: conversation)
    end

    # A shared location while a map-point question is open. It runs before the pin is
    # parked for a draft (#park_media): a citizen half-way through a ballot is
    # answering the ballot, and the drafting flow's own question for a place is not
    # the one that was asked.
    def handle_poll_location
      return false if conversation.pending_map_question_id.blank?

      location = reading.location

      return false if location.blank?

      ::Whatsapp::Polls::RecordMapPointService.call(
        conversation: conversation,
        latitude: location["latitude"],
        longitude: location["longitude"]
      )
    end

    # The one place a plain message is not a question for the assistant: the bot has
    # asked a free-text poll question and written down that it did, so the next words
    # the citizen sends are the answer to it.
    #
    # A tapped pill is never taken as text — its label is not something the citizen
    # wrote — and neither is a photo or a shared pin, which carry no words at all.
    def handle_open_answer_text
      return false if conversation.pending_open_question_id.blank?
      return false if reading.tapped_reply_id.present?
      return false if reading.text.blank?
      return false if ::Whatsapp::QrToken.carried_in?(reading.text)

      ::Whatsapp::Polls::RecordOpenAnswerService.call(
        conversation: conversation, text: reading.text
      )
    end

    # Where the ballot goes after a pill that settled a question without answering
    # one. Re-resolves the poll rather than trusting the marker, because the marker
    # outlives the poll it names.
    def advance_ballot
      poll = ::Poll.find_by(id: conversation.active_poll_id)

      return false if poll.blank?

      ::Whatsapp::Polls::AdvanceBallotService.call(conversation: conversation, poll: poll)
    end

    # The results where the phase has published any — one link, because a published
    # evaluation is a document rather than a set of entries. Everything else names the
    # newest contributions themselves: their titles, how old they are and their own
    # addresses, so reading what is in a phase no longer means leaving the chat. The
    # phase page closes the message off for everything the five named entries leave
    # out.
    def open_phase_contributions(projekt_phase)
      section = ::Whatsapp::PublishedResultsQuery.public_section_for(projekt_phase)

      return send_line_with_link(
        line: I18n.t("whatsapp.bot.phase.results", phase: projekt_phase.title),
        url: ::Whatsapp::ProjektLink.evaluation_url(projekt_phase)
      ) if section.present?

      query = ::Whatsapp::PhaseContributionsQuery.new(projekt_phase: projekt_phase)
      named = query.call.first(MAX_NAMED_CONTRIBUTIONS)

      return send_line_with_link(
        line: phase_contributions_intro(projekt_phase: projekt_phase, shown: 0, total: 0),
        url: ::Whatsapp::ProjektLink.phase_url(projekt_phase)
      ) if named.empty?

      send_phase_contributions(projekt_phase: projekt_phase, named: named, total: query.total)
    end

    # A list wherever any of the named entries can be opened in the chat, and plain
    # text where none can. Only proposals and budget investments carry a pill — an
    # event, a poll, a milestone or a notification is named with its link and left out
    # of the list rather than offered as a choice that would answer with nothing.
    def send_phase_contributions(projekt_phase:, named:, total:)
      phase_url = ::Whatsapp::ProjektLink.phase_url(projekt_phase)
      offered = named.each_with_index.filter_map do |entry, index|
        contribution_row(entry: entry, position: index + 1)
      end
      copy = phase_contributions_copy(projekt_phase: projekt_phase, named: named, total: total)

      body = phase_contributions_body(
        named: named, copy: copy, phase_url: phase_url, offered: offered.any?
      )

      return send_phase_contributions_list(body: body, copy: copy, offered: offered) if offered.any?

      ::Whatsapp::Send.text(account: account, body: body)

      true
    end

    def send_phase_contributions_list(body:, copy:, offered:)
      ::Whatsapp::Send.list(
        account: account,
        body: body,
        button_label: copy[:button_label].presence ||
                      I18n.t("whatsapp.bot.buttons.contribution_choose"),
        rows: offered
      )

      true
    end

    # Every fixed line of the message in one translation call, the entries' own dates
    # included: they are the bot's copy like the sentences around them, and a body in
    # the citizen's language carrying five German dates reads as two messages.
    # Deliberately not the titles or the addresses — a title is what its author wrote
    # and a URL a model rewrites is a dead end with no symptom until it is tapped.
    #
    # An entry may have no date at all, which is why the call has to be the one that
    # puts a blank line back where it found it: everything here is read back by
    # position.
    def phase_contributions_copy(projekt_phase:, named:, total:)
      fixed = [
        phase_contributions_intro(projekt_phase: projekt_phase, shown: named.size, total: total),
        I18n.t("whatsapp.bot.phase.contributions_page"),
        I18n.t("whatsapp.bot.phase.contributions_hint"),
        I18n.t("whatsapp.bot.buttons.contribution_choose")
      ]

      lines = ::Whatsapp::AiAssistant::BotCopyService.call(
        account: account, lines: fixed + named.map { |entry| entry[:description] }
      )

      {
        intro: lines[0], page: lines[1], hint: lines[2], button_label: lines[3],
        dates: lines.drop(fixed.size)
      }
    end

    # The phase type's own opening sentence, either closed off or extended to account
    # for what the message leaves unnamed.
    def phase_contributions_intro(projekt_phase:, shown:, total:)
      intro = phase_contributions_opening(projekt_phase)

      return I18n.t("whatsapp.bot.phase.contributions_all", intro: intro) if total <= shown

      I18n.t(
        "whatsapp.bot.phase.contributions_newest", intro: intro, shown: shown, total: total
      )
    end

    def phase_contributions_opening(projekt_phase)
      I18n.t(
        "#{CONTRIBUTIONS_INTRO_SCOPE}.#{projekt_phase.name}",
        phase: projekt_phase.title,
        default: I18n.t(
          "whatsapp.bot.phase.contributions_intro_fallback", phase: projekt_phase.title
        )
      )
    end

    def phase_contributions_body(named:, copy:, phase_url:, offered:)
      entries = named.zip(copy[:dates]).each_with_index.map do |(entry, date), index|
        contribution_entry(entry: entry, date: date, phase_url: phase_url, position: index + 1)
      end

      closing = phase_contributions_closing(page_line: copy[:page], phase_url: phase_url)
      hint = offered ? copy[:hint] : nil

      [copy[:intro], *entries, closing, hint].compact_blank.join("\n\n")
    end

    # Nothing at all where the projekt has no page: Whatsapp::ProjektLink answers nil
    # for one, and a closing sentence promising the rest of the contributions with no
    # address under it is a promise the message cannot keep.
    def phase_contributions_closing(page_line:, phase_url:)
      return if phase_url.blank?

      [page_line, phase_url].compact_blank.join("\n")
    end

    # The entry's own address is dropped where it is the phase page's: a milestone and
    # a projekt notification have no page of their own, so printing theirs would put
    # the same URL in the message twice — once as the way to one entry and once as the
    # way to everything.
    def contribution_entry(entry:, date:, phase_url:, position:)
      own_url = entry[:url] == phase_url ? nil : entry[:url]
      detail = [date, own_url].compact_blank.join("\n")

      ["#{position}. *#{entry[:title]}*", detail.presence].compact.join("\n")
    end

    # Through the same gate the assistant's rows go through rather than composed here:
    # it re-checks that the action is one that may be offered and that the record it
    # names still exists, which is the whole reason a row can be trusted to answer
    # with what it says.
    #
    # Numbered with the same position the entry carries in the message above, and not
    # for decoration: a row title holds twenty characters, so two proposals whose
    # titles agree for that long arrive as two rows reading identically, with the same
    # date under both and nothing on either saying which is which. The number is also
    # what lets the citizen pick the third one they just read about.
    def contribution_row(entry:, position:)
      return if entry[:action_id].blank?

      button = ::Whatsapp::AssistantActions.offered_button(
        spec: entry[:action_id], label: "#{position}. #{entry[:title]}", conversation: conversation
      )

      return if button.blank?
      return button if entry[:description].blank?

      button.merge(
        description: entry[:description].truncate(
          ::Ai::Tools::WhatsappAiAssistant::SendList::MAX_DESCRIPTION_LENGTH
        )
      )
    end

    # A row naming one contribution, answered on this side for the same reason a
    # phase's is: the row said which contribution it opens, so a note asking a model
    # which tool to reach for is a chance to open a different one. Falls through
    # wherever the pill can no longer be honoured — withdrawn, hidden or retired since
    # it was sent — and the assistant says so better than a fixed line would.
    def handle_contribution_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)
      action = flow_action&.fetch(:action)

      return false if action != ::Whatsapp::FlowActions::DIRECT_CONTRIBUTION_ACTION

      contribution = ::Whatsapp::ContributionPill.resolve(flow_action[:param])

      return false if contribution.blank?

      record_tap(action, flow_action[:param])

      open_contribution(contribution)
    end

    # The page where there is one, and the reason in words where there is none: a
    # proposal submitted into a moderated phase has no public page until it is
    # accepted, and the link it would otherwise be given is an error page. Saying so
    # is what lets the row be offered at all — every row of a list is selectable, so
    # the alternative was leaving the contribution out of the list that is meant to
    # be the citizen's complete history.
    def open_contribution(contribution)
      url = ::Whatsapp::PublishedResourceUrl.call(contribution)

      return send_line_with_link(
        line: I18n.t(contribution_opening_key(contribution), contribution: contribution.title),
        url: url
      ) if url.present?

      ::Whatsapp::Send.text(
        account: account,
        body: ::Whatsapp::AiAssistant::BotCopyService.line(
          account: account,
          body: I18n.t("whatsapp.bot.contribution.in_review", contribution: contribution.title)
        )
      )

      true
    end

    # Whose contribution it is decides the wording. The same pill is offered by the
    # citizen's own history and by a phase's list of what everyone has submitted, so
    # the line that greeted every one of them as "Ihr Beitrag" was calling a stranger's
    # proposal the citizen's own. Answered from the author rather than from which list
    # the pill came out of: a pill carries no memory of where it was offered, and a
    # citizen's own contribution reached through the phase list is still theirs.
    def contribution_opening_key(contribution)
      return "whatsapp.bot.contribution.open_other" if account.user_id.blank?
      return "whatsapp.bot.contribution.open_other" if contribution.author_id != account.user_id

      "whatsapp.bot.contribution.open"
    end

    # The sentence goes through the copy service and the address does not. Everything
    # the bot says is put into the citizen's language on its way out, but a URL handed
    # to a model is a URL a model can rewrite — and a mangled one is a dead end with no
    # symptom until it is tapped.
    def send_line_with_link(line:, url:)
      return false if url.blank?

      ::Whatsapp::Send.text(
        account: account,
        body: [::Whatsapp::AiAssistant::BotCopyService.line(account: account, body: line), url]
          .join("\n\n")
      )

      true
    end

    def handle_retry_tap
      return false if ::Whatsapp::Send.recovery_action_from(reading.tapped_reply_id) != :retry

      snapshot = conversation.retry_inbound.to_h

      return false if snapshot["text"].blank?

      record_tap(:retry, nil)

      answer(snapshot["text"], inbound_message_id: snapshot["message_id"])

      true
    end

    def send_bot_line(body)
      ::Whatsapp::Send.locale_text(account: account, body: body)
    end

    # A cancellation is the emptiest message the bot sends: the draft is gone, the
    # citizen asked for that, and what is left is a sentence with nothing to do after
    # it. The way back in goes under it rather than being left for them to type.
    #
    # The pill is a recovery one rather than one of the assistant's because both
    # callers sit above the assistant in the inbound chain: there is no turn here for
    # a model to have written a label in. The draft is discarded before this line
    # either way, so the translation the send makes on its way out can fail without
    # costing the cancellation — it costs the wording, which is what
    # BotCopyService falls back to the written copy for.
    def send_cancelled_line
      ::Whatsapp::Send.recovery(
        conversation: conversation, body: I18n.t("whatsapp.bot.cancelled"), actions: [:help]
      )
    end

    # The two taps that are an answer rather than a request: the citizen saying they
    # have no photo, or no particular place. Recorded so draft_status reports the
    # question as answered — the alternative is the assistant having to remember across
    # turns that it already asked, and asking someone for a photo they have just
    # declined reads as not having listened.
    #
    # No precondition and nothing irreversible: this writes down what they said, which
    # is why it is here rather than behind a tool of its own.
    SETTLED_BY_TAP = {
      image_skip: "photo_declined",
      location_skip: "location_stated"
    }.freeze

    def settle_slot_for(action)
      slot = SETTLED_BY_TAP[action]

      return if slot.blank?

      conversation.settle_slot!(slot)
    end

    # A pill from an older deploy, still sitting in someone's chat history and still
    # tappable forever. Answered rather than dropped: a tap that produces nothing at
    # all reads as a bot that has stopped working, and the citizen taps again. That it
    # no longer works is a fact the assistant needs, because otherwise the likeliest
    # reply is one that acts as though it had.
    def unhandled_tap_note(tapped_id)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :tap_unhandled, conversation: conversation, tapped: tapped_id
      )

      label = reading.tapped_reply_title.to_s.squish
      named = label.present? ? " \"#{label}\"" : ""

      "The citizen tapped a button#{named} from an earlier version of this bot, which no longer " \
        "does anything."
    end

    def record_tap(action, param)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :tap_dispatched, conversation: conversation, action: action, param: param
      )
    end

    # A photo and a shared pin carry no text at all, so the citizen has said nothing
    # for a model to read — and neither can be described to one without losing what
    # matters about it. Parked on the conversation, where the tool that attaches them
    # reads the real thing, and named in the state so the assistant knows one is
    # waiting.
    def park_media
      conversation.store_shared_image!(reading.image_id) if reading.image_id.present?

      location = reading.location

      return if location.blank?

      conversation.store_shared_location!(
        latitude: location["latitude"], longitude: location["longitude"]
      )
    end

    # A photo or a pin with no words beside it: the citizen has said nothing, so what
    # reaches the assistant is the fact that something arrived. Without this the turn
    # would be asked to answer an empty message, fail on it, and send the recovery
    # line — which is the one reply that says the bot is broken.
    #
    # The last line covers a sticker, a contact card, a document: something the portal
    # cannot use, which the citizen is owed an answer about rather than silence.
    def media_note
      return IMAGE_NOTE if conversation.shared_image_id.present?
      return LOCATION_NOTE if conversation.shared_location.present?

      UNREADABLE_NOTE
    end

    IMAGE_NOTE = "The citizen sent a photo with nothing written beside it. If a draft is open " \
                 "and this phase takes pictures, attach it with attach_draft_image and say so. " \
                 "Otherwise tell them there is nothing to attach it to right now.".freeze

    LOCATION_NOTE = "The citizen shared a location with nothing written beside it. If a draft is " \
                    "open, attach it with set_draft_location and say so. Otherwise tell them " \
                    "there is nothing to attach it to right now.".freeze

    UNREADABLE_NOTE = "The citizen sent something this bot cannot read — a sticker, a document or " \
                      "a contact. Say so briefly and ask them to write or say what they need.".freeze

    # A scanned QR code is not a message either. A phase code says which phase the
    # citizen chose; a projekt code says only which projekt, and which of its phases
    # is meant is the bot's inference rather than their decision — so the note says
    # which of the two it was and the assistant asks or acts accordingly.
    def entry_note(entry)
      return if entry.blank?

      ENTRY_NOTES[entry] || sprintf(ENTRY_NOTES.fetch(:projekt), projekt: entry_projekt_title)
    end

    ENTRY_NOTES = {
      phase: "The citizen arrived by scanning a QR code for one specific participation phase, " \
             "which is now the phase this submission belongs to. Tell them briefly what it is " \
             "and ask them what they want to contribute.",
      projekt: "The citizen arrived by scanning a QR code for the projekt \"%{projekt}\", which " \
               "has one phase open. Tell them what it is about, and offer to contribute to it.",
      projekt_choice: "The citizen arrived by scanning a QR code for a projekt with several " \
                      "phases open. Tell them what it is about and let them choose which phase " \
                      "they mean.",
      projekt_without_phase: "The citizen arrived by scanning a QR code for a projekt that has " \
                             "nothing open right now. Say so plainly, tell them what the projekt " \
                             "is about, and offer what else is running."
    }.freeze

    def entry_projekt_title
      projekt = conversation.projekt_phase&.projekt || entry_capture.projekt

      return "" if projekt.blank?

      ::Whatsapp::ProjektLink.title(projekt)
    end

    def entry_capture
      @entry_capture ||= ::Whatsapp::Inbound::EntryTokenCapture.new(
        conversation: conversation, reading: reading
      )
    end

    def capture_entry_token
      entry_capture.call
    end

    def account
      @account ||= @whatsapp_message.whatsapp_account
    end

    def conversation
      @conversation ||= account.conversation
    end

    # Only ever forwards: a retried or out-of-order delivery must not rewind the
    # conversation's clock.
    def latest_inbound_at
      [@whatsapp_message.sent_at || Time.current, previous_inbound_at].compact.max
    end

    # The conversation's clock as it stood before this message, kept because nothing
    # else can recover it: the write above moves last_inbound_at to now as the first
    # statement of the chain. The memo is filled before that write destroys it
    # because this method is the argument to it. The gap it measures is what decides
    # whether a reply greets, continues, or re-orients.
    def previous_inbound_at
      return @previous_inbound_at if defined?(@previous_inbound_at)

      @previous_inbound_at = conversation.last_inbound_at
    end

    def normalized_text
      reading.normalized_text
    end
end
