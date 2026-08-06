class Ai::Tools::WhatsappAiAssistant::ShowMenu < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Shows the citizen the tappable menu of what the portal currently has open, and " \
              "abandons whatever they were in the middle of. Use it when they ask what is " \
              "running, want to start over, want to cancel, or want to submit something without " \
              "naming a projekt. This sends the message itself — do not write one as well."

  # The menu is also how the deterministic bot answers an empty conversation,
  # so routing here reuses the exact reply the citizen would otherwise get.
  def execute
    conversation.reset_flow!

    ::Whatsapp::NextStepService.call(conversation: conversation)

    halt("Sent the citizen the menu of open participation phases.")
  end
end
