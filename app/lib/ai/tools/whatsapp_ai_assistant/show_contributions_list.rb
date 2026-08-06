class Ai::Tools::WhatsappAiAssistant::ShowContributionsList <
  Ai::Tools::WhatsappAiAssistant::BaseTool

  description "Sends the citizen everything they have submitted, with the link to each. Use it " \
              "when they want to see their own contributions — what did I submit, where is my " \
              "proposal, show me my ideas. Prefer this over list_my_contributions, which only " \
              "hands you the data to reason about when they ask about one particular " \
              "contribution. This sends the message itself: do not write one as well."

  def execute
    ::Whatsapp::Steps::ListContributionsService.call(conversation: conversation)

    halt("Sent the citizen their own contributions.")
  end
end
