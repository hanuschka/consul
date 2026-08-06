class Ai::Tools::WhatsappAiAssistant::ShowResultsList < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen the tappable list of finished phases whose results have been " \
              "published, where tapping one opens the evaluation. Use it whenever they ask what " \
              "came of a participation — results, outcome, evaluation, what was decided. This " \
              "sends the message itself: do not write one as well."

  def execute
    ::Whatsapp::Steps::ListResultsService.call(conversation: conversation)

    halt("Sent the citizen the list of published results.")
  end
end
