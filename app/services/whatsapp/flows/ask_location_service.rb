class Whatsapp::Flows::AskLocationService < Whatsapp::Flows::BaseService
  # The map pin, offered after the picture and before publishing, on a phase
  # whose map feature is on. Always optional, exactly as it is on the web
  # form: the second pill submits without one.
  #
  # Two messages rather than one, because WhatsApp's location request carries
  # no reply buttons of its own — the choice has to be an ordinary button
  # message, and the native picker is what the first pill then sends.
  def self.ask(conversation:, inbound_message_id: nil)
    new(conversation: conversation, inbound_message_id: inbound_message_id).ask
  end

  def self.request(conversation:)
    new(conversation: conversation).request
  end

  def self.remind(conversation:)
    new(conversation: conversation).remind
  end

  def self.re_ask(conversation:)
    new(conversation: conversation).re_ask
  end

  def self.handle_answer(conversation:, location:, verdict:, inbound_message_id: nil)
    new(conversation: conversation, inbound_message_id: inbound_message_id)
      .handle_answer(location, verdict)
  end

  def initialize(conversation:, inbound_message_id: nil)
    super(conversation: conversation)
    @inbound_message_id = inbound_message_id
  end

  # The pin is the last thing asked, after the picture: a citizen who has just
  # uploaded a photo should not be interrupted twice before their submission
  # goes in. A phase with the map switched off publishes on the spot, exactly
  # as it did before this step existed.
  def ask
    return publish if !@conversation.location_question_available?
    return if refuse_if_not_permitted

    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_LOCATION)

    send_choice("whatsapp.bot.proposal.ask_location")
  end

  # The picker itself. The step does not move: what this asks for is a
  # location message, and anything else at that step is answered by asking
  # again.
  #
  # A WhatsApp button stays tappable forever, so this one is reachable long
  # after the submission it belonged to was published. Opening the picker then
  # would take a pin nothing is waiting for — it arrives at an idle step and
  # is dropped — so a finished flow is restarted instead, the same answer the
  # preview gives a draft that is gone.
  def request
    if @conversation.draft_resource.blank?
      return Whatsapp::Flows::ResumeOrRestartService.restart(conversation: @conversation)
    end

    send_request("whatsapp.bot.proposal.location_request")
  end

  # The same picker with a line saying the last message was not a location.
  # The reminder is remembered on the conversation so the second miss
  # publishes instead of asking a third time — an optional field must not be
  # able to hold a finished submission.
  def remind
    @conversation.mark_location_reminded!

    send_request("whatsapp.bot.proposal.location_retry")
  end

  # The question put again after something interrupted it, which is not the
  # same thing as a miss. #remind spends the one reminder an optional field is
  # allowed, so resuming through it left the citizen's next non-pin message
  # publishing without a location — and said "that was not a location" about a
  # greeting. Neither the flag nor the step is touched here.
  def re_ask
    send_choice("whatsapp.bot.proposal.ask_location")
  end

  # A shared pin publishes, and so does a citizen saying there will not be
  # one: "die adresse weiß ich nicht" used to reach the same place by counting
  # as the one permitted miss, which spent a reminder to arrive at the answer
  # they had already given.
  #
  # Anything else is the citizen answering with words where the picker was
  # expected, so the picker is sent once more — and the second miss publishes
  # without a pin, because the pin is optional and a finished submission must
  # not be held for it.
  def handle_answer(location, verdict)
    return attach_and_publish(location) if location.present?
    return publish if verdict == :skip
    return publish if @conversation.location_reminded?

    remind
  end

  private

    def attach_and_publish(location)
      # No draft left to pin — a retention purge, an admin deleting the phase.
      # Restarted rather than reported as a failed pin: offering to share it
      # again would be offering it for a submission that no longer exists, and
      # the way out would land in a publish that has nothing to publish. Same
      # answer #request already gives a tapped picker whose draft is gone.
      if draft_resource.blank?
        return Whatsapp::Flows::ResumeOrRestartService.restart(conversation: @conversation)
      end

      return announce_attach_failure if !attach(location["latitude"], location["longitude"])

      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.proposal.location_received")
      )

      publish
    end

    # A pin the citizen shared through the picker and believes is on the map,
    # which could not be written. Publishing anyway put the contribution online
    # without the one thing they had just deliberately added, and never said so
    # — they only find out by looking at the map. Answered the way a photo that
    # cannot be used already is: name the failure and offer the step again.
    #
    # The step is deliberately not moved and the reminder flag not spent. Both
    # ways on are on this message — share again, or publish without a pin — so
    # the choice is theirs rather than the next message's.
    def announce_attach_failure
      send_choice("whatsapp.bot.proposal.location_failed")
    end

    # The pin the citizen shared through WhatsApp's own picker, written onto
    # the draft.
    #
    # It replaces whatever PersistDraftService may have geocoded out of the
    # free text rather than joining it — a position the citizen chose outranks
    # one inferred from their wording — which is `MapLocation.create_pin!`'s
    # own behaviour, shared with the geocoder so the two cannot write
    # different pins. Returns true when the pin was written, which is what
    # decides whether the caller publishes or reports the failure.
    def attach(latitude, longitude)
      return false if draft_resource.blank?
      return false if latitude.blank? || longitude.blank?

      MapLocation.create_pin!(
        mappable: draft_resource, latitude: latitude, longitude: longitude
      )

      true
    rescue StandardError => e
      report(e, "location attach")

      false
    end

    def publish
      Whatsapp::Flows::PublishResultService.call(
        conversation: @conversation, inbound_message_id: @inbound_message_id
      )
    end

    def send_request(body_key)
      Whatsapp::Send.location_request(
        account: account,
        body: Whatsapp.phrase(body_key)
      )
    end

    # The two messages that offer the pair of pills — the question, and the
    # failure that puts it again. Parameterised so both provably carry the same
    # two ways on, which is the whole point of the failure branch.
    def send_choice(body_key)
      Whatsapp::Send.buttons(
        account: account,
        body: Whatsapp.phrase(body_key),
        buttons: buttons
      )
    end

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :location_share, label_key: "whatsapp.bot.buttons.location_share"
        ),
        Whatsapp::FlowActions.button(
          action: :location_skip, label_key: "whatsapp.bot.buttons.location_skip"
        )
      ]
    end
end
