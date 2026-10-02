class Ai::Tools::WhatsappAiAssistant::RemoveDraftLocation <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  # The way back from a place the citizen did not mean. A place read from their
  # words is only ever proposed, but once they have agreed to it — or shared a pin
  # and thought better of it — nothing else takes it off again, and "no, not
  # there" has to be something the bot can act on rather than only apologise for.
  description "Takes the place off the citizen's draft: drops the place read from their words " \
              "that is waiting for their answer, and removes a pin already attached. Call it " \
              "when they say the place is wrong or that they would rather go without one. A " \
              "pin stays optional afterwards. Sends nothing."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_LOCATION
  end

  def execute
    if draft_resource.blank?
      no_draft_error
    elsif attached_pin.blank? && !waiting_location?
      nothing_to_remove_error
    else
      remove
    end
  end

  private

    def attached_pin
      draft_resource.map_location
    end

    def waiting_location?
      conversation.proposed_location.present? || conversation.shared_location.present?
    end

    def remove
      attached_pin&.destroy!
      draft_resource.reload_map_location

      # The block the citizen confirms names the pin, so a yes given with it was a
      # yes to a different contribution.
      conversation.record_removed_location!

      {
        removed: true,
        hint: "Tell them the contribution has no place on the map now. Ask for the right place " \
              "only if they want to give one."
      }
    end

    def nothing_to_remove_error
      { error: "The draft has no place attached and none is waiting, so there is nothing to " \
               "remove." }
    end
end
