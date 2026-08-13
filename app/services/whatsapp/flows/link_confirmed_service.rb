class Whatsapp::Flows::LinkConfirmedService < Whatsapp::Flows::BaseService
  # Catalog A1 tail. The success confirmation flows straight into the discovery
  # offer rather than ending the conversation: the moment someone has just
  # linked is the one moment they are certain to be looking at the chat.
  def call
    @conversation.reset_flow!

    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.linked")
    )

    Whatsapp::Outbound.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.discovery_offer"),
      buttons: buttons
    )
  end

  private

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :discover, label_key: "whatsapp.bot.buttons.show_projekts"
        ),
        Whatsapp::FlowActions.button(
          action: :dismiss, label_key: "whatsapp.bot.buttons.no_thanks"
        )
      ]
    end
end
