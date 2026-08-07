class Ai::Tools::WhatsappAiAssistant::Archive::ShowMenu < ::Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Shows the citizen the central menu — submitting an idea, their own " \
              "contributions, browsing the running projekts, results of finished phases — and " \
              "abandons whatever they were in the middle of. Use it when they ask what they can " \
              "do here, want to start over, want to cancel, or want something the menu covers " \
              "but have not said which. This sends the message itself — do not write one as well."

  # The same menu the deterministic bot answers an empty conversation with, so
  # routing here gives the citizen the reply they would otherwise have got.
  def execute
    conversation.reset_flow!

    ::Whatsapp::Archive::MainMenuService.call(conversation: conversation)

    halt("Sent the citizen the central menu.")
  end
end
