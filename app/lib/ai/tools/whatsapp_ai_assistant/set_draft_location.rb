class Ai::Tools::WhatsappAiAssistant::SetDraftLocation <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Writes a place onto the citizen's draft: the pin they have just shared, or the " \
              "place read from their words once they have said it is the right one. Call it as " \
              "soon as a shared location arrives while a draft is open, or when they agree to " \
              "the place draft_status reports as waiting for their answer — never before they " \
              "have agreed to it. It reads the coordinates itself, so it needs nothing from " \
              "you: never retype a position. A pin is always optional, and one they shared " \
              "outranks anything read from their wording. A pin outside the projekt's area is " \
              "refused."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_LOCATION
  end

  def execute
    return no_draft_error if draft_resource.blank?

    pin = waiting_pin

    return nothing_waiting_error if pin.blank?

    refusal = refuse_if_not_permitted

    return refusal if refusal.present?

    inside_area?(pin) ? write(pin) : outside_area_error
  end

  private

    # A shared pin is what the citizen deliberately chose, so it wins over a place
    # the drafting call read out of their words.
    def waiting_pin
      shared = conversation.shared_location.to_h

      if shared["latitude"].present? && shared["longitude"].present?
        shared
      else
        conversation.proposed_location.presence
      end
    end

    # Asked of the proposed place too, although the lookup already kept it inside:
    # the phase can have moved its map since the place was proposed.
    def inside_area?(pin)
      ::ProposalAiDraft::PinArea.new(projekt_phase).contains?(pin["latitude"], pin["longitude"])
    end

    # MapLocation.create_pin! replaces whatever pin the draft already had rather
    # than joining it, which is the same behaviour the web form has — and sharing
    # the writer with the geocoder is what stops the two producing different pins
    # for one draft.
    #
    # Cleared whether or not it worked, so a pin that could not be written cannot be
    # re-attached to whatever the citizen does next.
    def write(pin)
      ::MapLocation.create_pin!(
        mappable: draft_resource, latitude: pin["latitude"], longitude: pin["longitude"]
      )

      # create_pin! builds a new pin from the MapLocation side, which leaves the
      # draft's own association holding whatever it read before — so the preview
      # sent next in this turn would show the draft without it.
      draft_resource.reload_map_location

      name = place_name(pin)

      # The pin is named in the block the citizen confirms, so a yes given before it
      # was written was a yes to a contribution without a place on the map.
      conversation.record_attached_location!(name)

      {
        attached: true,
        place: name,
        hint: "Say the place has been noted, then show them the contribution with " \
              "show_draft_for_confirmation and ask whether it can go in."
      }.compact
    rescue StandardError => e
      conversation.clear_waiting_locations!

      report(e)

      write_failed_error
    end

    # A proposed place already carries the name it was found under. A shared pin
    # carries only coordinates, so it is looked up once here rather than on every
    # preview of the draft.
    def place_name(pin)
      pin["name"].presence ||
        ::Polls::MapPointAddress.new(latitude: pin["latitude"], longitude: pin["longitude"]).call
    end

    def nothing_waiting_error
      { error: "No location is waiting. Ask the citizen to share the pin through WhatsApp's own " \
               "location button, which request_location opens, or to name the place in words." }
    end

    # Used up either way: a pin that stayed waiting would be attached by the next
    # call as though nothing had been said about it.
    def outside_area_error
      conversation.clear_waiting_locations!

      { error: "That place is outside the area of this projekt, so it cannot go on the " \
               "contribution's map and nothing was attached. Tell the citizen so, and offer to " \
               "share a pin inside the projekt's area or to go on without one." }
    end

    # A pin the citizen shared and believes is on the map, which could not be
    # written. Publishing anyway would put the contribution online without the one
    # thing they had just deliberately added, and never say so — they would only find
    # out by looking at the map.
    def write_failed_error
      { error: "The pin could not be saved. Tell the citizen so and offer either to share it " \
               "again or to go on without one — do not publish as though it had worked." }
    end

    def report(exception)
      Rails.logger.error(
        "[Whatsapp] location attach failed: #{exception.class} - #{exception.message}"
      )

      Sentry.capture_exception(exception, extra: { whatsapp_conversation_id: conversation.id })
    end
end
