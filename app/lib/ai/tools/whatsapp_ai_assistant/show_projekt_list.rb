class Ai::Tools::WhatsappAiAssistant::ShowProjektList < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen the tappable list of participation projekts running right now, " \
              "where tapping one opens its page. Use it whenever they ask to see the projekts — " \
              "which projekts are running, show me the projects, what is going on in my town — " \
              "rather than sending them to the menu to find this themselves. This sends the " \
              "message itself: do not write one as well."

  def execute
    ::Whatsapp::Steps::ListProjektsService.call(conversation: conversation)

    halt("Sent the citizen the list of running projekts.")
  end
end
