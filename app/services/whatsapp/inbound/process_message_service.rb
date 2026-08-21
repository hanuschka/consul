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
  # - An unsubscribed number is answered by nothing at all. It used to reach a
  #   classifier — a whole model call whose only question was whether the message was
  #   an opt-in, which the keyword above now answers — and being conversed with is
  #   the one thing unsubscribing asked us not to do.
  # - A voice note is transcribed just ahead of the keyword gate, the first text
  #   consumer. The "could not read it" reply goes out there, but the chain runs on.
  # - Cancelling is read before anything else can act on the message, for the same
  #   reason as the stop keyword: leaving a half-written submission must not depend
  #   on a provider being reachable. A text-less voice note halts only after that
  #   gate, because a tap is never audio.
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
    return if account.opt_out_at.present?

    disclose_ai

    return if handle_cancel_tap
    return if reading.tapped_reply_id.blank? && reading.unreadable_voice_note?

    entry = capture_entry_token

    park_media

    inbound_note = tap_note || entry_note(entry) || reading.text.presence || media_note

    return answer_tap(inbound_note) if reading.tapped_reply_id.present?

    answer(inbound_note)
  end

  private

    # The same turn as any other, with the waiting marked on the tapped message
    # for the whole of it. Only taps take this route: the typing bubble covers
    # every other kind of message and covers none of theirs.
    #
    # The mark is withdrawn however the turn ended — answered, degraded to the
    # recovery line, or raised — because an hourglass left on a message that has
    # already been replied to says the opposite of what it is for.
    def answer_tap(inbound_text)
      ::Whatsapp::Send.acknowledge_tap(account: account, message_id: reading.message_id)

      answer(inbound_text)
    ensure
      ::Whatsapp::Send.withdraw_tap_acknowledgement(
        account: account, message_id: reading.message_id
      )
    end

    # The one place the assistant is asked anything, whether what reaches it is the
    # citizen's own words, a note saying which button they tapped, or a note saying
    # which QR code they scanned. All three are the same thing to a model reading one
    # conversation: something happened, and a reply is owed.
    def answer(inbound_text)
      return send_unavailable_line if !::Ai::Settings.ai_available?

      result = ::Whatsapp::AiAssistant::RouterService.call(
        conversation: conversation,
        inbound_text: inbound_text,
        inbound_message_id: reading.message_id,
        previous_inbound_at: previous_inbound_at
      )

      return if result.success?

      send_unavailable_line
    end

    # The whole deterministic surface left, and it is one sentence with one button.
    # It is reached for a provider that cannot be reached, a turn that timed out, a
    # blank reply, a tool loop that ran away, and a tenant with AI switched off —
    # which is a change in the deployment story rather than in this method: before,
    # nine services degraded to fixed copy and a keyless tenant had a working bot.
    def send_unavailable_line
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :assistant_unavailable, conversation: conversation
      )

      ::Whatsapp::Send.recovery_without_assistant(
        conversation: conversation,
        body: I18n.t("whatsapp.bot.assistant_unavailable"),
        actions: [:cancel]
      )
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

      recovery = ::Whatsapp::Send.recovery_action_from(tapped_id)

      return tapped_line(action: recovery) if recovery.present?

      flow_action = ::Whatsapp::FlowActions.parse(tapped_id)

      return unhandled_tap_note(tapped_id) if flow_action.blank?

      record_tap(flow_action[:action], flow_action[:param])
      settle_slot_for(flow_action[:action])

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
