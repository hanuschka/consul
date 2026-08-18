class Whatsapp::Flows::CancelService < Whatsapp::Flows::BaseService
  # Catalog C21. Aborts the open submission and says so.
  #
  # It used to end there, in plain text, and a citizen who had just cancelled
  # had nothing to tap: the reply named no way back in, and the help pill it
  # briefly offered instead answered a question nobody had asked. One button to
  # the main menu is the way back, and it is a button rather than the three
  # menu options themselves so the cancellation reads as an ending.
  #
  # Reached only while a flow is open. The same word typed at any other moment
  # is the section E opt-out, and the two are separated in the gate chain rather
  # than here — see Inbound::ProcessMessageService.
  # A submission set aside for a side trip is thrown away here too. Cancelling
  # is the citizen saying they are done writing, and leaving the parked one
  # behind would offer them a draft back a message after they asked to be rid of
  # one — reset_flow! deliberately preserves it, so this is where it goes.
  def call
    @conversation.discard_parked_flow!
    @conversation.reset_flow!

    Whatsapp::Send.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.cancelled"),
      buttons: [
        Whatsapp::FlowActions.button(
          action: :main_menu, label_key: "whatsapp.bot.buttons.main_menu"
        )
      ]
    )
  end
end
