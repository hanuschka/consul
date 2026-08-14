class Whatsapp::Inbound::AssistantRouting
  # The single holder of "one model reading per message". Only #handled? may
  # run the router, at most once; the verdict readers may trigger only the
  # (memoized) classifier. The spine used to keep the router's hand-off in an
  # instance variable read two gates later — here it is an explicit result
  # the spine holds and passes into the step dispatch, so the contract is
  # visible in signatures instead of in a side channel.
  def initialize(conversation:, account:, reading:, pending_question:)
    @conversation = conversation
    @account = account
    @reading = reading
    @pending_question = pending_question
  end

  # Everything above the assistant in the gate chain is protocol rather than
  # dialogue — the typed STOP word, a tapped pill, a scanned QR code. The
  # assistant sees only what is left, and hands back anything the flow owns,
  # together with what it made of the message.
  #
  # An unlinked guest submitter skips it: half its tools act on a Consul
  # account, and a guest reaching them would only produce errors it cannot
  # explain. Their one model reading is the classifier's instead, so either
  # way a message is read exactly once.
  def handled?
    return @handled if defined?(@handled)

    @handled = router_answered?
  end

  # The verdict this message already got from its one reading — the router's
  # hand-off for a linked citizen, the classifier for a guest — so no step
  # ever pays a second completion to re-derive it. Every degraded path — AI
  # switched off, a router turn that failed — reads as :answer, which every
  # step treats as "just the message" and answers by re-asking.
  #
  # Lazy on purpose: a message that never reaches a verdict-consuming step
  # must not pay a classifier call it never paid before.
  def verdict
    return @handoff[:verdict] if @handoff.present?
    return message_intent.verdict if classifier_routes?

    :answer
  end

  def correction
    return @handoff[:correction] if @handoff.present?
    return message_intent.correction if classifier_routes?

    nil
  end

  # Who this message's one model reading comes from. The router serves a
  # linked, subscribed citizen; the classifier serves everyone it will not —
  # guests and unlinked numbers, whose whole path is the deterministic flow,
  # and opted-out numbers, whose only open question is opting back in.
  def classifier_routes?
    @account.user.blank? || @account.opt_out_at.present?
  end

  # Asked once per message: the spine's channel gate reads the channel
  # verdicts off it, and the step handlers read the flow verdicts off the
  # same result.
  def message_intent
    @message_intent ||= Whatsapp::AiAssistant::MessageIntentService.call(
      conversation: @conversation,
      inbound_text: @reading.text,
      interaction_open: interaction_open?
    )
  end

  # A word that cannot mean "leave the channel" dismisses whatever the bot
  # last asked. Any step other than idle is that, and so is an idle
  # conversation holding a question: the assistant's own button replies leave
  # the step at idle, so the step alone cannot tell the two apart. The
  # pending-question flag arrives already consumed by the spine.
  def interaction_open?
    return true if !@conversation.idle?

    @pending_question
  end

  private

    def router_answered?
      return false if !::Ai::Settings.ai_available?
      return false if @account.user.blank?
      return false if @reading.tapped_reply_id.present?

      # A shared location is an answer to the step that asked for it, and it
      # carries no text at all — routing it would pay for a completion on an
      # empty message and could answer a pin with conversation.
      return false if @reading.location.present?

      result = Whatsapp::AiAssistant::RouterService.call(
        conversation: @conversation,
        inbound_text: @reading.text,
        inbound_message_id: @reading.message_id
      )

      return false if !result.success?

      # A hand-off is not "routed": the flow still answers. What it made of
      # the message travels along, so the step dispatch acts on the router's
      # one reading instead of asking a second model what was just decided.
      if result.outcome == :flow
        @handoff = { verdict: result.decision, correction: result.correction }

        return false
      end

      true
    end
end
