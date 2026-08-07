class Ai::Tools::WhatsappAiAssistant::Archive::ToggleProjektFollow <
  ::Ai::Tools::WhatsappAiAssistant::BaseTool

  description "Starts or stops following one projekt, so the citizen is told on WhatsApp when " \
              "something happens in it. The same follow the website's button sets, so following " \
              "here shows up there. Calling it on a projekt they already follow unfollows it. " \
              "Take the projekt_id from list_open_phases or describe_projekt. This sends the " \
              "confirmation itself — do not write one as well."

  params do
    integer :projekt_id, description: "Id of the projekt to follow or unfollow"
  end

  def execute(projekt_id:)
    handled = ::Whatsapp::Archive::MenuActionService.call(
      conversation: conversation,
      scope: :projekt,
      record_id: projekt_id.to_i,
      action: :follow
    )

    return { error: "No projekt with that id is open to citizens right now." } if !handled

    halt("Changed the citizen's follow state for projekt #{projekt_id}.")
  end
end
