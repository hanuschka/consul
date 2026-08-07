class Ai::Tools::WhatsappAiAssistant::StartUnlink < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Asks the citizen to confirm unlinking their account from this number. Use it " \
              "when they say they want to unlink, disconnect, or delete the connection between " \
              "this number and their account. It only asks — nothing is unlinked until they " \
              "confirm. This sends the message itself."

  def execute
    return not_linked_error if user.blank?

    ::Whatsapp::Flows::UnlinkService.call(conversation: conversation)

    halt("Asked the citizen to confirm unlinking.")
  end

  private

    def not_linked_error
      { error: "This number is not linked to an account, so there is nothing to unlink." }
    end
end
