class Ai::Tools::WhatsappAiAssistant::OpenProjekt < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Opens one projekt's own card: its description, its link, and buttons leading to " \
              "that projekt's phases, contributions, dates, progress and results. Use it when " \
              "the citizen names a projekt they want to look into, rather than only describing " \
              "it in text. Take the projekt_id from list_open_phases or describe_projekt. " \
              "This sends the message itself — do not write one as well."

  params do
    integer :projekt_id, description: "Id of the projekt to open"
  end

  def execute(projekt_id:)
    handled = ::Whatsapp::MenuActionService.call(
      conversation: conversation,
      scope: :projekt,
      record_id: projekt_id.to_i,
      action: :card
    )

    return { error: "No projekt with that id is open to citizens right now." } if !handled

    halt("Opened the card for projekt #{projekt_id}.")
  end
end
