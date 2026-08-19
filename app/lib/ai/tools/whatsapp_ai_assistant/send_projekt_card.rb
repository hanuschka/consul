class Ai::Tools::WhatsappAiAssistant::SendProjektCard < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen one projekt as a card — its title, a short summary of what it is " \
              "about, its picture and its link — in a message of its own. Call this whenever you " \
              "point the citizen at one specific projekt or are asked to tell them about one, " \
              "instead of writing its address into your reply. Identified by name rather than by " \
              "id, so it reaches finished projekts as well as running ones. The card carries the " \
              "link and the summary, so do not repeat either in the reply you write afterwards."

  params do
    string :projekt_name, description: "The project name as the citizen wrote it"
  end

  # By name rather than by an open phase's id, which is what it took before: a
  # projekt the citizen asks about is routinely one that has finished, and no
  # listing tool could have handed the model an id for it. Carded only where it
  # was still open, the bot answered every other projekt with an address written
  # out in prose — and the requirement is that a projekt it informs about always
  # comes with a link.
  def execute(projekt_name:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    ::Whatsapp::Flows::SendProjektCardService.call(conversation: conversation, projekt: projekt)

    # Halts like every other tool that sends its own message: the card already
    # carries the title, the summary, the picture and the link, so a further
    # completion would pay for a sentence that may only repeat them.
    halt("Sent the projekt card, which carries the title, a summary, the picture and the link.")
  end
end
