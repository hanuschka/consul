class Whatsapp::Flows::LinkDeclinedService < Whatsapp::Flows::BaseService
  # Catalog A3. Declining is not commented on negatively — what is lost is
  # stated plainly and the discovery offer still stands, because someone who
  # will not link may still want to read the portal.
  def call
    @conversation.reset_flow!

    Whatsapp::Outbound.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.declined"),
      buttons: buttons
    )
  end

  private

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :discover_public, label_key: "whatsapp.bot.buttons.show_current_projekts"
        ),
        Whatsapp::FlowActions.button(
          action: :dismiss, label_key: "whatsapp.bot.buttons.got_it"
        )
      ]
    end
end
