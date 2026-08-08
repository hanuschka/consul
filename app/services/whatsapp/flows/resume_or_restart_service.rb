class Whatsapp::Flows::ResumeOrRestartService < Whatsapp::Flows::BaseService
  # Catalog C23. Sent as a reply the next time the citizen writes in, never
  # pushed: WhatsApp only carries a freeform message within 24 hours of their
  # last one, and the staleness threshold is 3600 minutes — so by the time a
  # draft is stale the bot could not reach out even if it wanted to.
  def call
    @conversation.update!(step: "awaiting_resume_decision")

    Whatsapp::Outbound.buttons(
      account: account,
      body: I18n.t("whatsapp.bot.proposal.resume"),
      buttons: buttons
    )
  end

  private

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :resume, label_key: "whatsapp.bot.buttons.resume"
        ),
        Whatsapp::FlowActions.button(
          action: :restart, label_key: "whatsapp.bot.buttons.restart"
        )
      ]
    end
end
