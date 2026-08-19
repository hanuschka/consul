class Ai::Tools::WhatsappAiAssistant::SetDraftLocation <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Writes the pin the citizen has just shared onto their draft. Call it as soon as a " \
              "location arrives while a draft is open — draft_status says whether one is " \
              "waiting. It reads the coordinates the citizen actually shared, so it needs " \
              "nothing from you: never retype a position. A pin is always optional, and one " \
              "they chose outranks anything inferred from their wording, so it replaces what " \
              "the drafting call may have guessed from the text."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_LOCATION
  end

  def execute
    return no_draft_error if draft_resource.blank?

    pin = conversation.shared_location.to_h

    return nothing_shared_error if pin["latitude"].blank? || pin["longitude"].blank?

    refusal = refuse_if_not_permitted

    return refusal if refusal.present?

    write(pin)
  end

  private

    # MapLocation.create_pin! replaces whatever was geocoded out of the free text
    # rather than joining it, which is the same behaviour the web form has — and
    # sharing the writer with the geocoder is what stops the two producing different
    # pins for one draft.
    #
    # Cleared whether or not it worked, so a pin that could not be written cannot be
    # re-attached to whatever the citizen does next.
    def write(pin)
      ::MapLocation.create_pin!(
        mappable: draft_resource, latitude: pin["latitude"], longitude: pin["longitude"]
      )

      conversation.clear_shared_location!

      {
        attached: true,
        hint: "Say the place has been noted and ask whether the contribution can go in."
      }
    rescue StandardError => e
      conversation.clear_shared_location!

      report(e)

      write_failed_error
    end

    def nothing_shared_error
      { error: "No location is waiting. Ask the citizen to share the pin through WhatsApp's own " \
               "location button, which request_location opens, or to name the place in words." }
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
