class Ai::Tools::WhatsappAiAssistant::ShowHelp < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the overview of everything this bot can do. Use it when the citizen asks " \
              "what you can do, what happens here, how this works, or seems lost. This sends " \
              "the message itself — do not write your own list of capabilities."

  def execute
    ::Whatsapp::Flows::HelpService.call(conversation: conversation)

    halt("Sent the help overview.")
  end
end
