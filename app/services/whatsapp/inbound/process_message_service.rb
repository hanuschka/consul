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
  #   The one thing it does not decide is what "Stopp" means in the middle of a
  #   contribution, a comment or a vote. That is handed on to the assistant, which
  #   asks once, and the keyword falls back to leaving whenever no model answers.
  # - An unsubscribed number reaches no model and gets nothing about the portal
  #   answered: being conversed with is the one thing unsubscribing asked us not to
  #   do. It used to reach a classifier — a whole model call whose only question was
  #   whether the message was an opt-in, which the keyword above now answers. What
  #   it does get — on its first message after leaving, then at most once a day —
  #   is the one line naming the word that brings it back, because the keyword that
  #   took it out of the channel is also the ordinary word for abandoning a draft.
  # - A voice note is transcribed just ahead of the keyword gate, the first text
  #   consumer. The "could not read it" reply goes out there, but the chain runs on.
  # - Cancelling is read before anything else can act on the message, for the same
  #   reason as the stop keyword: leaving a half-written submission must not depend
  #   on a provider being reachable. A text-less voice note halts only after that
  #   gate, because a tap is never audio.
  # - Help, tapped or typed as the bare word, is answered from the locale copy
  #   rather than by the assistant: it names the same words, privacy page and
  #   contact every time, and it leaves whatever is in progress where it was.
  # - The pill that means "back to the beginning" is read here for that reason
  #   as well, and its gate is the one that does not halt: clearing the phase is
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
  #
  # Turkish, Arabic, Ukrainian and Russian follow German and English, because a
  # citizen writing in their own language must be able to leave during an outage
  # too. Their cancel words count as leaving on purpose: missing someone who
  # wanted out is the failure nothing may allow, and in the middle of a step the
  # assistant still asks first. Arabic is listed with and without the hamza,
  # since both are how people type it.
  OPT_OUT_KEYWORDS = [
    "stop", "stopp", "abmelden", "unsubscribe",
    "dur", "iptal", "abonelikten çık",
    "توقف", "إيقاف", "ايقاف", "إلغاء", "الغاء", "إلغاء الاشتراك", "الغاء الاشتراك",
    "стоп", "відписатися", "скасувати",
    "отписаться", "отмена"
  ].map { |word| ::Whatsapp::Inbound::MessageReading.keyword_form(word) }.freeze

  # The way back in for a number that left. Deterministic for the same reason
  # leaving is: an unsubscribed number reaches no model, so the only thing that can
  # read this is Ruby.
  OPT_IN_KEYWORDS = [
    "start", "anmelden", "subscribe",
    "başla", "abone ol",
    "ابدأ", "ابدا", "اشتراك",
    "старт", "підписатися",
    "подписаться"
  ].map { |word| ::Whatsapp::Inbound::MessageReading.keyword_form(word) }.freeze

  # The one of them the citizen is told to write, by the confirmation of leaving
  # and by the reminder after it — both have to name a word this list still reads.
  def self.opt_in_keyword
    OPT_IN_KEYWORDS.first.upcase
  end

  # The word alone, answered like the pill. Anything around it — "hilfe bei meinem
  # Vorschlag" — is a question for the assistant, which sends the same help through
  # show_help where that is what it asks for.
  HELP_KEYWORDS = %w[hilfe help].map do |word|
    ::Whatsapp::Inbound::MessageReading.keyword_form(word)
  end.freeze

  # How many of a phase's contributions the reply names in words, where none of them
  # can be opened in the chat and a list has nothing to offer. Fewer than the ten
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
    conversation.hold_stop_question!

    # Every message is acknowledged, tapped ones included: a tap that produces no
    # bubble reads as a tap that did not arrive, and the citizen taps again.
    ::Whatsapp::Send.typing(message_id: reading.message_id)

    announce_unreadable_voice_note

    return if handle_channel_keywords
    return offer_way_back_in if account.opt_out_at.present?

    settle_stop_question

    disclose_ai

    track_submission_wish

    return if handle_cancel_tap
    return if handle_help_request
    return if handle_retry_tap
    return if handle_phase_tap
    return if handle_contribution_tap
    return if handle_votes_tap
    return if handle_poll_answer_tap
    return if handle_poll_weight_tap
    return if handle_poll_done_tap
    return if handle_poll_skip_tap
    return if handle_poll_location

    apply_start_over_tap

    return if reading.tapped_reply_id.blank? && reading.unreadable_voice_note?

    entry = capture_entry_token

    park_media

    inbound_note =
      tap_note || entry_note(entry) || deferred_opt_out_note || reading.text.presence ||
      media_note

    # Read before the turn, because the turn is what may end the ballot: a citizen
    # who asks to submit something instead has left it, and start_draft! replaces the
    # whole context with the assistant's own history, markers included.
    ballot_in_flight = conversation.active_poll_id

    answer(
      inbound_note, inbound_message_id: reading.message_id, citizen_words: citizen_words
    )

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
    #
    # `replayed_tool_results` are the completed tool results a retry snapshot carried: a
    # retry that fails as well has done nothing itself, and must still say it went through.
    # They are handed to the conversation before the turn, so the router's failure report
    # names them as well.
    def answer(inbound_text, inbound_message_id:, citizen_words:, replayed_tool_results: [])
      return send_unavailable_line if !::Ai::Settings.ai_available?

      if replayed_tool_results.any?
        conversation.carry_completed_tool_results!(replayed_tool_results)
      end

      result = route(
        inbound_text, inbound_message_id: inbound_message_id, citizen_words: citizen_words
      )
      @turn_answered = result.success?

      return conversation.clear_retry_inbound! if result.success?
      return honour_deferred_opt_out if @opt_out_deferred

      completed_tool_results = conversation.completed_tool_results.uniq

      if completed_tool_results.any?
        return offer_retry_after_completed_tools(
          completed_tool_results, inbound_message_id: inbound_message_id, reason: result.error
        )
      end

      # The note describing a tap is snapshotted as the text it is: what the retry
      # replays is the sentence the assistant was given, which already says which
      # button was pressed. The citizen's words travel with it, so a free-text
      # answer whose turn failed can still be recorded from the retry.
      conversation.store_retry_inbound!(
        text: inbound_text, message_id: inbound_message_id, citizen_words: citizen_words
      )

      send_retryable_unavailable_line(reason: result.error)
    end

    # One turn of the assistant, for #answer and for the reply after a discard,
    # which handles its own failure.
    def route(inbound_text, inbound_message_id:, citizen_words:)
      ::Whatsapp::AiAssistant::RouterService.call(
        conversation: conversation,
        inbound_text: inbound_text,
        citizen_words: citizen_words,
        inbound_message_id: inbound_message_id,
        typing_message_id: reading.message_id,
        previous_inbound_at: previous_inbound_at
      )
    end

    # A turn that put a comment on the page, counted a support or followed a projekt and
    # only then failed to write its reply. The citizen is told what went through before
    # being told what did not, because the bare "I can't answer you" under their own
    # published comment leaves them unable to tell whether it went in.
    #
    # And the retry replays the tools' own answers instead of the inbound that asked for
    # them. That turn was never stored, and the tools that completed have already used
    # up what they acted on — the stashed comment, the draft — so the same request put
    # again is answered with "nothing has been written down" about a comment that is on
    # the page. The citizen's words stay out: the note is not something they wrote.
    #
    # The line names what went through in the model's own words where a tool sent
    # nothing of its own — a followed projekt, a switched notification — because there
    # the failed reply was the whole confirmation, and "that worked" under nothing says
    # nothing. What follows from it is the assistant's to say once it can answer again.
    def offer_retry_after_completed_tools(completed_tool_results, inbound_message_id:, reason:)
      conversation.store_retry_inbound!(
        text: ::Whatsapp::CompletionNotes.retry_after_completed(completed_tool_results),
        message_id: inbound_message_id,
        citizen_words: nil,
        completed_tool_results: completed_tool_results
      )

      send_unavailable_line_offering(
        body: ::Whatsapp.copy(
          "whatsapp.bot.assistant_unavailable_after_action",
          completed: completed_actions_sentence(completed_tool_results)
        ),
        actions: %i[retry cancel],
        reason: reason
      )
    end

    # The completion lines the model wrote with its calls — written before the reply
    # that failed, so they are there when it is not. A tool that sent its own
    # confirmation left none, and the plain "that worked" sits under that message.
    def completed_actions_sentence(completed_tool_results)
      completion_lines = completed_tool_results.filter_map { |entry| entry["completion_line"] }.uniq

      if completion_lines.empty?
        return ::Whatsapp.copy("whatsapp.bot.assistant_unavailable_action_done")
      end

      completion_lines.join(" ")
    end

    # The message as the citizen wrote it, where the turn answers their words
    # rather than a note about them: never the label of a tapped pill, which is
    # not something they wrote, and never a message carrying a QR token.
    def citizen_words
      return if reading.tapped_reply_id.present?
      return if reading.text.blank?
      return if ::Whatsapp::QrToken.carried_in?(reading.text)

      reading.text
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
    #
    # Reported as a warning rather than an error: nothing broke in this turn, but a
    # tenant whose citizens all read this line is one nobody would otherwise notice.
    def send_unavailable_line
      ::Whatsapp::AiAssistant::TurnFailureReport.message(
        reason: :ai_unavailable, conversation: conversation, level: :warning
      )

      send_unavailable_line_offering(
        body: ::Whatsapp.copy("whatsapp.bot.assistant_unavailable"),
        actions: [:cancel],
        reason: "ai_unavailable"
      )
    end

    def send_retryable_unavailable_line(reason:)
      send_unavailable_line_offering(
        body: ::Whatsapp.copy("whatsapp.bot.assistant_unavailable_retryable"),
        actions: %i[retry cancel],
        reason: reason
      )
    end

    def send_unavailable_line_offering(body:, actions:, reason:)
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :assistant_unavailable,
        conversation: conversation,
        reason: reason,
        completed: conversation.completed_tool_names.join(",").presence
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
    # Held back too where the turn swapped the ballot for another one. That is said
    # by Whatsapp::Polls::OfferBallotService as it begins the second, which is the
    # only moment both are still nameable and the new question has not gone out yet.
    # And where the turn recorded a typed answer: the tool that recorded it has
    # already sent the ballot's next message.
    #
    # And once per question only. Put again after every detour, a question is a
    # script running under the conversation rather than a part of it — a map
    # question re-sent its picker under each reply until the citizen was trapped in
    # it. After the one re-ask the question stays in the state, and bringing it
    # back is the assistant's call (Whatsapp::Conversation#resumed_poll_question_ids).
    #
    # Never under the stop question: the next ballot question sent after "only the
    # vote, or all messages?" answers it on the citizen's behalf.
    #
    # Never without a word either. The assistant's reply is what says why the question
    # comes again (SystemPromptService#ballot_line asks it to); a turn that failed
    # wrote none, so a fixed line says it instead of the question arriving alone.
    def resume_ballot(poll_id)
      return if poll_id.blank?
      return if @opt_out_deferred
      return if ::Current.whatsapp_ballot_message_sent_in_turn
      return if conversation.reload.active_poll_id != poll_id
      return if conversation.unsaved_submission?

      poll = ::Poll.find_by(id: poll_id)

      return if poll.blank?

      owed_question_id =
        ::Whatsapp::Polls::OwedQuestionQuery.for(conversation: conversation)&.question&.id

      return if conversation.resumed_poll_question_ids.include?(owed_question_id)

      if owed_question_id.present?
        conversation.record_resumed_poll_question!(owed_question_id)
      end

      if owed_question_id.present? && !@turn_answered
        send_bot_line(::Whatsapp.copy("whatsapp.bot.poll.question_again"))
      end

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
        body: ::Whatsapp.copy("whatsapp.bot.transcription_failed"),
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
    # and "STOP" ends all messages for good. With nothing in progress it can only
    # mean the second, and that is honoured here before any model is asked. In the
    # middle of a contribution, a comment or a vote it can mean either, and which
    # is the assistant's to read from the conversation rather than a rule's to
    # guess: guessed "cancel", a citizen who wanted out stays subscribed; guessed
    # "leave", a citizen who wanted to drop a comment is unsubscribed without a word.
    #
    # The assistant asks once. The keyword after that question is honoured here
    # again, and so is one that arrives when no model can be reached to ask it.
    def handle_opt_out
      return defer_opt_out if opt_out_ambiguous?

      ::Whatsapp::Accounts::MessageDeliveryService.disable(conversation: conversation)

      true
    end

    def opt_out_ambiguous?
      conversation.step_in_progress? &&
        !conversation.stop_question_asked? &&
        ::Ai::Settings.ai_available?
    end

    # False, so the chain runs on: the disclosure still goes out ahead of the
    # reply, and the reply is the assistant's.
    def defer_opt_out
      @opt_out_deferred = true
      conversation.ask_stop_question!

      false
    end

    # Any other message answers the question, whatever it said.
    def settle_stop_question
      return if @opt_out_deferred

      conversation.clear_stop_question!
    end

    # The deferred keyword whose turn could not be written. Asking was the
    # assistant's part, and without it the keyword means what it means everywhere
    # else: leaving the channel must not depend on a provider being reachable.
    # No retry is stored, because there is nothing left to retry.
    def honour_deferred_opt_out
      ::Whatsapp::Accounts::MessageDeliveryService.disable(conversation: conversation)
    end

    def deferred_opt_out_note
      return if !@opt_out_deferred

      sprintf(DEFERRED_OPT_OUT_NOTE, text: reading.text.to_s.squish)
    end

    DEFERRED_OPT_OUT_NOTE = "The citizen wrote \"%{text}\" while in the middle of a contribution, " \
                            "a comment or a vote, or just after being asked for one. It may mean " \
                            "stopping only that, or receiving no more messages from us at all. " \
                            "Ask them once, in one short " \
                            "question, which they mean, and offer the cancel button for stopping " \
                            "only this. If they want no more messages, call stop_messages.".freeze

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
    # Throttled off what the bot has said to this number since it left rather than
    # off a column of its own, and the message log answers exactly this question
    # for exactly this case: a broadcast skips an opted-out number and the
    # assistant never reaches one, so the only lines written to one are the
    # confirmation of leaving and this one.
    #
    # The first message after leaving is always answered. Counting the
    # confirmation as "the last thing said" is what held the way back for a week
    # from the one citizen most likely to need it — the one who is still writing.
    OPT_OUT_REMINDER_INTERVAL = 1.day

    def offer_way_back_in
      return if !way_back_in_due?

      send_bot_line(
        ::Whatsapp.copy(
          "whatsapp.bot.compliance.opted_out_reminder",
          keyword: self.class.opt_in_keyword
        )
      )
    end

    # Two rows are enough to tell the cases apart: none or only the confirmation
    # means no reminder yet, and otherwise the newest row is the last reminder.
    def way_back_in_due?
      spoken_since_opt_out_at =
        account
          .whatsapp_messages
          .outbound
          .where(created_at: account.opt_out_at..)
          .order(created_at: :desc)
          .limit(2)
          .pluck(:created_at)

      return true if spoken_since_opt_out_at.size < 2

      spoken_since_opt_out_at.first < OPT_OUT_REMINDER_INTERVAL.ago
    end

    # Once per number rather than once per 24-hour window: a regular who reads it
    # every day stops reading it at all. Sending it dismisses the typing bubble asked
    # for above, and everything below still has its wait ahead of it.
    def disclose_ai
      return if account.ai_disclosed?

      send_bot_line(
        ::Whatsapp.copy(
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
      return @resolved_tap_note if @resolved_tap_note.present?

      return ::Whatsapp::StartOverNotes.for(conversation) if start_over_tap?

      recovery = ::Whatsapp::Send.recovery_action_from(tapped_id)

      return tapped_line(action: recovery) if recovery.present?

      flow_action = ::Whatsapp::FlowActions.parse(tapped_id)

      return unhandled_tap_note(tapped_id) if flow_action.blank?

      record_tap(flow_action[:action], flow_action[:param])
      settle_slot_for(flow_action[:action])
      discard_declined_photo(flow_action[:action])
      open_revision_for(flow_action[:action])

      support_tap_note(action: flow_action[:action], param: flow_action[:param]) ||
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
    # Which way it goes is carried in the id, written from the vote when the pill was
    # composed (Whatsapp::AssistantActions#directed_action) — so a tap does what its
    # label said. It used to be read here, off the vote as it stood when the tap
    # arrived, and a citizen tapping twice while the reply was still on its way had
    # the support registered by the first tap and taken back by the second. Now the
    # second finds it already done and nothing changes.
    #
    # The retired `support` id comes through here too. Every support pill the bot has
    # ever sent is still sitting in a chat history and still tappable, and it only
    # ever meant the one thing. So does `support_toggle` from before the direction
    # was carried: it says nothing about which way it went, so it still reads the
    # vote on arrival.
    SUPPORT_TAP_ACTIONS = %i[support_register support_withdraw support_toggle support].freeze

    # What a support given on the tap is recorded as among the turn's completed tool
    # results. No tool ran, but the write is the same one support_proposal makes, and
    # a turn that fails after it owes the citizen the same "that worked".
    SUPPORT_BUTTON = "support_button".freeze

    def support_tap_note(action:, param:)
      return if !SUPPORT_TAP_ACTIONS.include?(action)
      return if param.blank?
      return NOT_LINKED_NOTE if account.user.blank?

      proposal = ::Proposal.not_retired.find_by(id: param.to_i)

      return SUPPORT_GONE_NOTE if proposal.blank?

      case action
      when :support_withdraw then withdrawn_support_note(proposal)
      when :support_toggle then toggled_support_note(proposal)
      else registered_support_note(proposal)
      end
    end

    def toggled_support_note(proposal)
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

      conversation.note_completed_tool_result!(
        tool: SUPPORT_BUTTON,
        result: { completed: true, supported: true, supports: supports, hint: REGISTERED_NOTE }
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

      conversation.note_completed_tool_result!(
        tool: SUPPORT_BUTTON,
        result: { completed: true, withdrawn: true, supports: supports, hint: WITHDRAWN_NOTE }
      )

      WITHDRAWN_NOTE
    end

    # The rule underneath rather than the sentence, the same way a tool reports a
    # refusal: the sentence is the assistant's to write for the question they
    # actually asked, in their language. Nothing has been sent on any of these paths,
    # so unlike the two notes above there is nothing to tell it not to repeat.
    #
    # The two "already" answers are not mistakes. Usually the same pill was tapped
    # twice while the reply to the first tap was still on its way; otherwise the
    # vote moved on the projekt page or in another chat after the pill was sent.
    # Both are the state the citizen wanted, so neither is reported as a failure —
    # and the pill offered beside it is the one that goes the other way.
    def support_refusal_note(reason, proposal)
      return already_supported_note(proposal) if reason == :already_supported
      return not_supported_note(proposal) if reason == :not_supported
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
                      "to them, and that message is the confirmation: do not say again that it " \
                      "is registered, and repeat none of it. Your reply is the way on only — a " \
                      "short line on what they can do next, with its buttons. Do not invite " \
                      "them to support anything else, and do not say it is final or cannot be " \
                      "taken back — its support button, offered again, takes it back.".freeze

    WITHDRAWN_NOTE = "The citizen tapped the support button on a contribution they already " \
                     "supported, so the support has been taken back. The contribution, the " \
                     "count as it now stands and its address have already been sent to them, " \
                     "and that message is the confirmation: do not say again that it is " \
                     "withdrawn, and repeat none of it. Your reply is the way on only — a short " \
                     "line on what they can do next, with its buttons. Do not ask why and do " \
                     "not talk them back into it — its support button, offered again, " \
                     "supports it again.".freeze

    def already_supported_note(proposal)
      "They already support that contribution, and nothing changed. Say so plainly rather " \
        "than as a failure, and offer support_toggle-#{proposal.id} beside it — it now takes " \
        "the support back."
    end

    def not_supported_note(proposal)
      "They do not support that contribution, so there was nothing to take back and nothing " \
        "changed. Say so plainly rather than as a failure, and offer " \
        "support_toggle-#{proposal.id} beside it — it now gives the support."
    end

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

      conversation.begin_start_over!
    end

    # Both namespaces are read here: the start-over pill is built from the catalog and
    # keeps its catalog id, because every one already sent is still sitting in a chat
    # history and still tappable. `help` left this list when it got an answer of its
    # own (handle_help_request) — as a start-over it cleared the phase under a draft
    # and was answered with the overview.
    START_OVER_ACTIONS = %i[main_menu].freeze

    def start_over_tap?
      tapped_id = reading.tapped_reply_id

      return false if tapped_id.blank?

      action = ::Whatsapp::Send.recovery_action_from(tapped_id) ||
        ::Whatsapp::FlowActions.parse(tapped_id)&.fetch(:action)

      START_OVER_ACTIONS.include?(action)
    end

    # Cancelling is the one tap that does its own work, and its gate is up in the
    # chain with the stop keyword for the same reason: abandoning a submission must
    # not depend on a provider being reachable. Recovery ids are read before catalog
    # ones — the two namespaces are built by different modules from different
    # prefixes, so this can never swallow a catalog pill.
    def handle_cancel_tap
      return false if ::Whatsapp::Send.recovery_action_from(reading.tapped_reply_id) != :cancel

      record_tap(:cancel, nil)

      if conversation.revision_open?
        revert_change
      else
        discard_work
      end

      true
    end

    # While a change the citizen asked for is open, the change is all the pill takes
    # back: it reads "Änderung verwerfen" then, and the comment or the draft they had
    # already read is still what they want.
    def revert_change
      # Read before the revert, which closes what it describes.
      note = [tapped_line(action: :cancel), ::Whatsapp::RevertNotes.for(conversation)].join(" ")

      conversation.revert_revision!

      answer_cancel(note, fallback_key: "whatsapp.bot.change_reverted")
    end

    def discard_work
      # Read before the discard, which clears what it describes.
      note = [tapped_line(action: :cancel), ::Whatsapp::DiscardNotes.for(conversation)].join(" ")

      conversation.discard_draft!

      answer_cancel(note, fallback_key: "whatsapp.bot.cancelled")
    end

    # Nothing is cleared: a draft, a comment or a ballot in progress is still there
    # when the citizen writes again, and the assistant carries on from it.
    def handle_help_request
      help_tap = ::Whatsapp::Send.recovery_action_from(reading.tapped_reply_id) == :help

      return false if !help_tap && !typed_help_keyword?

      record_tap(:help, nil) if help_tap

      ::Whatsapp::HelpMessage.deliver(conversation)

      true
    end

    # Never for a tapped pill, whose label the citizen did not write.
    def typed_help_keyword?
      reading.tapped_reply_id.blank? && HELP_KEYWORDS.include?(normalized_text)
    end

    # The discard or the revert is done by now and never waits on a model; only the
    # line after it does. The assistant writes it where one answers, so it can name
    # what went and offer the way on, and the fixed line stands in where none does: a
    # failed turn must not leave the citizen without word of what the tap did.
    def answer_cancel(note, fallback_key:)
      return send_cancel_line(fallback_key) if !::Ai::Settings.ai_available?

      result = route(note, inbound_message_id: reading.message_id, citizen_words: nil)

      return if result.success?

      send_cancel_line(fallback_key)
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
    # is the one that knows what "again" means. A snapshot taken after a completed action
    # holds a note saying what was done rather than the request, so replaying it carries
    # the conversation on instead of acting a second time.
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
    #
    # It also falls through for a phase that is taken part in on the website, but
    # resolved: the phase is looked up and checked here, and what reaches the
    # assistant is a note saying what it is (#open_phase). The fixed line and the bare
    # link that used to answer it left the citizen with nothing to tap.
    def handle_phase_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)
      action = flow_action&.fetch(:action)

      return false if !::Whatsapp::FlowActions.direct_phase?(action)

      phase_id, from = ::Whatsapp::FlowActions.parse_page_param(flow_action[:param])
      projekt_phase = tapped_phase(phase_id)

      return false if projekt_phase.blank?

      record_tap(action, flow_action[:param])

      return open_phase(projekt_phase) if action == :phase_open

      open_phase_contributions(projekt_phase, from: from)
    end

    # "Vorschlag erstellen" is the citizen asking to submit something, and where the
    # assistant answers it with the projekts to choose from, the card sent for the one
    # they pick is the place that wish has to be honoured — so it is written down here,
    # on the tap, where it is a fact rather than a reading of their words. Recorded
    # whatever phase the conversation last had: after a published contribution the
    # phase stays set, and the tap on staging that lost its wish came from exactly
    # there. Where the assistant opens a submission straight away instead,
    # start_draft! replaces the context and the wish goes with it; where the citizen
    # goes on to something else, it lapses (Whatsapp::Conversation::SUBMISSION_WISH_TTL).
    def track_submission_wish
      action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)&.dig(:action)

      return if action != :submit_proposal

      conversation.record_submission_wish!
    end

    # The projekt card's last row, which opens every vote of its projekt. Answered
    # here for the reason the phase pills are: handed to the assistant, the tap was a
    # model choosing a tool, and twice it chose one of the ballots over the list.
    # Falls through where the projekt is gone or has no open vote left.
    def handle_votes_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)
      action = flow_action&.fetch(:action)

      if action != ::Whatsapp::FlowActions::DIRECT_VOTES_ACTION
        return false
      end

      projekt_id, from = ::Whatsapp::FlowActions.parse_page_param(flow_action[:param])
      projekt = ::Projekt.find_by(id: projekt_id.to_i)

      if !::Whatsapp::EligiblePhasesQuery.projekt_visible?(projekt)
        return false
      end

      listed = ::Whatsapp::Polls::ListProjektPollsService.call(
        account: account, projekt: projekt, from: from
      )

      return false if !listed

      record_tap(action, flow_action[:param])

      true
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
    #
    # The link goes out in the assistant's reply, with a way on beside it: the tap is
    # handed over as a note (#website_phase_note) and false lets the message reach
    # the turn. Only with the assistant unavailable is it the fixed line and the link
    # alone, because a tap answered with "unavailable" loses the page it asked for.
    def open_phase(projekt_phase)
      return true if ::Whatsapp::Polls::OfferBallotService.call(
        conversation: conversation, projekt_phase: projekt_phase
      )

      if !::Ai::Settings.ai_available?
        return send_line_with_link(
          line: ::Whatsapp.copy("whatsapp.bot.phase.open", phase: projekt_phase.title),
          url: ::Whatsapp::ProjektLink.participation_url(projekt_phase)
        )
      end

      @resolved_tap_note = website_phase_note(projekt_phase)

      false
    end

    # What the tap resolved to, in facts rather than in instructions: which ways on
    # make sense — the projekt, its events, another of its phases — is the
    # assistant's to judge. The address stays on this side: the note names the pill,
    # and reply_with_actions writes the page in by it (Whatsapp::PillPageUrl).
    def website_phase_note(projekt_phase)
      projekt = projekt_phase.projekt
      spec = "phase_open-#{projekt_phase.id}"

      [
        tapped_line(action: :phase_open, param: projekt_phase.id),
        "It is the phase \"#{projekt_phase.title}\" (#{projekt_phase.name}) of the projekt " \
          "\"#{::Whatsapp::ProjektLink.title(projekt)}\" (id #{projekt.id}), which is taken " \
          "part in on the website, not in this chat.",
        page_note(spec, url: ::Whatsapp::ProjektLink.participation_url(projekt_phase))
      ].join(" ")
    end

    # How the page gets into the reply, or that there is none to give.
    def page_note(spec, url:)
      return "It has no page the bot can link to." if url.blank?

      "Its page goes under your reply by passing link \"#{spec}\" to reply_with_actions."
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
        conversation: conversation, question_answers: [question_answer]
      )
    end

    # "I have picked everything I want" on a multiple-choice question
    # (Whatsapp::Polls::FinishMultipleQuestionService).
    #
    # Honoured only for the question the bot is actually in the middle of asking. The
    # pill sits in the chat history like every other, and tapped a day later it would
    # otherwise reopen a ballot that has been finished and closed off.
    #
    # Tapped before anything was chosen, the question is put again with a line saying
    # why — it used to come back on its own, which read as a tap the bot had not seen.
    def handle_poll_done_tap
      flow_action = ::Whatsapp::FlowActions.parse(reading.tapped_reply_id)

      return false if flow_action&.fetch(:action) != :poll_done
      return false if conversation.open_multiple_question_id.to_i != flow_action[:param].to_i

      record_tap(:poll_done, flow_action[:param])

      outcome = ::Whatsapp::Polls::FinishMultipleQuestionService.call(conversation: conversation)

      if outcome != ::Whatsapp::Polls::FinishMultipleQuestionService::NOTHING_CHOSEN
        return outcome
      end

      send_bot_line(::Whatsapp.copy("whatsapp.bot.poll.nothing_chosen"))

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
    # newest contributions themselves, so reading what is in a phase no longer means
    # leaving the chat.
    #
    # Where the entries can be opened here — proposals and budget investments — they
    # are the rows of a list, a page at a time, with a row for the next page. They
    # used to be named in the text above a list of the same five, with the phase page
    # closing the message off for the rest: seventeen entries were five in the chat,
    # and the rows cut each title at its twenty-fourth character. Where none can be
    # opened — an event, a poll, a milestone, a notification — they are named in the
    # text with their own addresses, as before.
    def open_phase_contributions(projekt_phase, from: 0)
      section = ::Whatsapp::PublishedResultsQuery.public_section_for(projekt_phase)

      return send_line_with_link(
        line: ::Whatsapp.copy("whatsapp.bot.phase.results", phase: projekt_phase.title),
        url: ::Whatsapp::ProjektLink.evaluation_url(projekt_phase)
      ) if section.present?

      query = ::Whatsapp::PhaseContributionsQuery.new(projekt_phase: projekt_phase)
      total = query.total
      page_start = contributions_page_start(from, total)
      entries = query.call(from: page_start)

      return send_line_with_link(
        line: phase_contributions_intro(projekt_phase: projekt_phase, shown: 0, total: 0),
        url: ::Whatsapp::ProjektLink.phase_url(projekt_phase)
      ) if entries.empty?

      if entries.any? { |entry| entry[:action_id].present? }
        return send_phase_contributions_page(
          projekt_phase: projekt_phase, entries: entries, total: total, from: page_start
        )
      end

      send_phase_contributions(
        projekt_phase: projekt_phase, named: entries.first(MAX_NAMED_CONTRIBUTIONS), total: total
      )
    end

    # A pill tapped long after it was sent may point past the end of a list that has
    # shrunk since, and the first page is the answer the citizen can read.
    def contributions_page_start(from, total)
      page_start = ::Whatsapp::ListWindow.offset(from)

      return 0 if page_start >= total

      page_start
    end

    # Named in the text, for the entries none of which can be opened in the chat.
    def send_phase_contributions(projekt_phase:, named:, total:)
      phase_url = ::Whatsapp::ProjektLink.phase_url(projekt_phase)
      copy = phase_contributions_copy(projekt_phase: projekt_phase, named: named, total: total)

      ::Whatsapp::Send.text(
        account: account,
        body: phase_contributions_body(named: named, copy: copy, phase_url: phase_url)
      )

      true
    end

    # One page of entries the citizen can open one by one, as the rows of a list: the
    # title split over the row's two lines (Whatsapp::ListRowText) with its date
    # underneath, and a last row for the page after it. The text above says only what
    # the list is and where the phase page is — naming the entries there as well would
    # repeat the list, and past five of them outgrow what an interactive body holds.
    def send_phase_contributions_page(projekt_phase:, entries:, total:, from:)
      phase_url = ::Whatsapp::ProjektLink.phase_url(projekt_phase)
      copy = phase_contributions_copy(
        projekt_phase: projekt_phase, named: entries, total: total, from: from
      )
      rows = entries.each_with_index.filter_map do |entry, index|
        contribution_row(entry: entry, position: from + index + 1, date: copy[:dates][index])
      end
      more_row = contributions_more_row(
        projekt_phase: projekt_phase, next_from: from + entries.size, total: total, copy: copy
      )
      closing = phase_contributions_closing(page_line: copy[:page], phase_url: phase_url)

      send_phase_contributions_list(
        body: [copy[:intro], closing, copy[:hint]].compact_blank.join("\n\n"),
        copy: copy,
        offered: [*rows, more_row].compact
      )
    end

    def send_phase_contributions_list(body:, copy:, offered:)
      ::Whatsapp::Send.list(
        account: account,
        body: body,
        button_label: copy[:button_label].presence ||
                      ::Whatsapp.copy("whatsapp.bot.buttons.contribution_choose"),
        rows: offered
      )

      true
    end

    # The same pill the card's "Beiträge ansehen" row carries, with the offset of the
    # next page beside the phase (Whatsapp::FlowActions.page_param), so the tap is
    # answered by #handle_phase_tap like the first page was.
    def contributions_more_row(projekt_phase:, next_from:, total:, copy:)
      return if next_from >= total

      {
        id: ::Whatsapp::FlowActions.id_for(
          action: :phase_contributions,
          param: ::Whatsapp::FlowActions.page_param(record_id: projekt_phase.id, from: next_from)
        ),
        title: copy[:show_more].presence || ::Whatsapp.copy("whatsapp.bot.buttons.show_more")
      }
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
    def phase_contributions_copy(projekt_phase:, named:, total:, from: 0)
      fixed = [
        phase_contributions_intro(
          projekt_phase: projekt_phase, shown: named.size, total: total, from: from
        ),
        ::Whatsapp.copy("whatsapp.bot.phase.contributions_page"),
        ::Whatsapp.copy("whatsapp.bot.phase.contributions_hint"),
        ::Whatsapp.copy("whatsapp.bot.buttons.contribution_choose"),
        ::Whatsapp.copy("whatsapp.bot.buttons.show_more")
      ]

      lines = ::Whatsapp::AiAssistant::BotCopyService.call(
        account: account, lines: fixed + named.map { |entry| entry[:description] }
      )

      {
        intro: lines[0], page: lines[1], hint: lines[2], button_label: lines[3],
        show_more: lines[4], dates: lines.drop(fixed.size)
      }
    end

    # The phase type's own opening sentence, either closed off or extended to account
    # for what the message leaves unnamed — and, past the first page, for where in the
    # whole this page is.
    def phase_contributions_intro(projekt_phase:, shown:, total:, from: 0)
      intro = phase_contributions_opening(projekt_phase)

      if from.positive?
        return ::Whatsapp.copy(
          "whatsapp.bot.phase.contributions_range",
          intro: intro, first: from + 1, last: from + shown, total: total
        )
      end

      return ::Whatsapp.copy("whatsapp.bot.phase.contributions_all", intro: intro) if total <= shown

      ::Whatsapp.copy(
        "whatsapp.bot.phase.contributions_newest", intro: intro, shown: shown, total: total
      )
    end

    def phase_contributions_opening(projekt_phase)
      ::Whatsapp.copy(
        "#{CONTRIBUTIONS_INTRO_SCOPE}.#{projekt_phase.name}",
        phase: projekt_phase.title,
        default: ::Whatsapp.copy(
          "whatsapp.bot.phase.contributions_intro_fallback", phase: projekt_phase.title
        )
      )
    end

    def phase_contributions_body(named:, copy:, phase_url:)
      entries = named.zip(copy[:dates]).each_with_index.map do |(entry, date), index|
        contribution_entry(entry: entry, date: date, phase_url: phase_url, position: index + 1)
      end

      closing = phase_contributions_closing(page_line: copy[:page], phase_url: phase_url)

      [copy[:intro], *entries, closing].compact_blank.join("\n\n")
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
    # Numbered by the entry's place in the whole list, and not for decoration: two
    # proposals may carry the same title and the same date, and the number is then the
    # one thing on either row saying which is which. The title is split over the row's
    # two lines rather than cut at its twenty-fourth character, so what it says past
    # that — "Anwohnerparken in de…" — is on the screen too.
    def contribution_row(entry:, position:, date:)
      return if entry[:action_id].blank?

      lines = ::Whatsapp::ListRowText.call(name: "#{position}. #{entry[:title]}", notes: [date])

      return if lines.blank?

      button = ::Whatsapp::AssistantActions.offered_row(
        spec: entry[:action_id], label: lines[:title], conversation: conversation
      )

      return if button.blank?
      return button if lines[:description].blank?

      button.merge(description: lines[:description])
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

      contribution = ::Whatsapp::ContributionPill.resolve(flow_action[:param], user: account.user)

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
    #
    # Answered by the assistant from the same facts find_contribution gives it — its
    # supports, whether the citizen wrote or supported it, the pill that supports it
    # — so that a contribution opened by a tap is not a bare link where the same one
    # asked about by name comes with a way on. As with a phase, the fixed lines are
    # what is left for when the assistant is unavailable.
    def open_contribution(contribution)
      if ::Ai::Settings.ai_available?
        @resolved_tap_note = contribution_tap_note(contribution)

        return false
      end

      url = ::Whatsapp::PublishedResourceUrl.call(contribution)

      return send_line_with_link(
        line: ::Whatsapp.copy(
          contribution_opening_key(contribution), contribution: contribution.title
        ),
        url: url
      ) if url.present?

      ::Whatsapp::Send.text(
        account: account,
        body: ::Whatsapp::AiAssistant::BotCopyService.line(
          account: account,
          body: ::Whatsapp.copy("whatsapp.bot.contribution.in_review", contribution: contribution.title)
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

    # Whose it is travels among the facts (written_by_you) rather than as a choice of
    # wording, for the same reason #contribution_opening_key reads it off the author.
    # A contribution without a public page is named as the one still being reviewed,
    # the reason the fixed line gave, so the model is not left to guess at a link.
    def contribution_tap_note(contribution)
      action = ::Whatsapp::FlowActions::DIRECT_CONTRIBUTION_ACTION
      param = ::Whatsapp::ContributionPill.param_for(contribution)
      url = ::Whatsapp::PublishedResourceUrl.call(contribution)
      facts = ::Whatsapp::ContributionFacts.call(contribution, user: account.user)

      [
        tapped_line(action: action, param: param),
        "It opens this contribution: #{facts.to_json}.",
        contribution_page_note("#{action}-#{param}", url: url)
      ].join(" ")
    end

    def contribution_page_note(spec, url:)
      if url.blank?
        return "It is still being reviewed and has no public page until it is released."
      end

      page_note(spec, url: url)
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

      answer(
        snapshot["text"],
        inbound_message_id: snapshot["message_id"],
        citizen_words: snapshot["citizen_words"],
        replayed_tool_results: Array(snapshot["completed_tool_results"])
      )

      true
    end

    def send_bot_line(body)
      ::Whatsapp::Send.locale_text(account: account, body: body)
    end

    # The fallback after a discard or a revert, for when no assistant answered
    # (#answer_cancel): the tap did what the citizen asked, and what is left is a
    # sentence with nothing to do after it. The way back in goes under it rather than
    # being left for them to type.
    #
    # The pill is a recovery one rather than one of the assistant's because this
    # runs where no turn was answered: there is no model here to have written a
    # label in. The draft is discarded before this line
    # either way, so the translation the send makes on its way out can fail without
    # costing the cancellation — it costs the wording, which is what
    # BotCopyService falls back to the written copy for.
    def send_cancel_line(copy_key)
      ::Whatsapp::Send.recovery(
        conversation: conversation, body: ::Whatsapp.copy(copy_key), actions: [:help]
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

    # A photo that arrived unasked waits under the question about it, and the
    # notices went out with that question — so a "no" that left it parked would
    # let the next attach_draft_image put the photo they declined on the draft.
    def discard_declined_photo(action)
      return if action != :image_skip

      conversation.clear_shared_image!
    end

    # The two taps that ask to change what the citizen has just read in a preview:
    # the comment and the draft. What they read is kept from here until the changed
    # version is shown, so the cancel pill under the request for the change can take
    # back the change alone (#revert_change). Writing it down is all this does — the
    # tap still reaches the assistant as the line it always was.
    def open_revision_for(action)
      case action
      when :comment_prompt then conversation.begin_comment_revision!
      when :draft_revise then conversation.begin_draft_revision!
      end
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
                 "and this phase takes pictures, call attach_draft_image: it attaches the " \
                 "photo, or first sends the notices about pictures where they have not been " \
                 "shown yet. Otherwise tell them there is nothing to attach it to right " \
                 "now.".freeze

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
