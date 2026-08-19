class Ai::Tools::WhatsappAiAssistant::ShowHelp < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the overview of everything this bot can do, as a list. Only for a citizen " \
              "asking what this service *is* — what happens here, how it works, who they are " \
              "talking to — or one who seems lost after you have already tried answering. " \
              "\"What can I do today?\" is NOT this: that asks what there is to do right now, " \
              "so read what is open and answer with reply_with_actions instead. This sends the " \
              "message itself — do not write your own list of capabilities."

  # Parked first, exactly as ShowMainMenu does, because this lands on the same
  # MainMenuService.greeting — and that begins with reset_flow!, which nils
  # draft_resource and slices the context down to the parked flow. Without the
  # park a citizen who asks "wie funktioniert das?" halfway through writing a
  # contribution loses it, with the record left orphaned and unreachable. The
  # tool descriptions now steer a lost citizen here more readily than before,
  # which turns a latent hole into a reachable one.
  def execute
    park_open_flow!

    ::Whatsapp::Flows::MainMenuService.greeting(conversation: conversation)

    halt("Sent the help overview.")
  end
end
