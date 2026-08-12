class Whatsapp::Flows::FirstContactService < Whatsapp::Flows::BaseService
  # Catalog A1. Four messages, in this order and as separate bubbles rather than
  # one: the AI disclosure is a platform obligation and has to stand on its own,
  # the consent line has to be readable next to the button that accepts it, and
  # burying either inside a longer body is what makes them easy to miss.
  #
  # The portal's own greeting heads them. It is what the admin wrote for this
  # moment — the /adm field says so — and saying it here is what lets the main
  # menu stop repeating the introduction to citizens who have already read it.
  def call
    Whatsapp::Outbound.text(account: account, body: ::Whatsapp.onboarding_greeting)
    Whatsapp::Outbound.text(account: account, body: disclosure)
    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.link_question")
    )

    account.mark_ai_disclosed!
    @conversation.update!(step: "awaiting_link_decision")

    Whatsapp::Outbound.buttons(
      account: account,
      body: consent,
      buttons: Whatsapp::FlowActions.link_decision_buttons
    )
  end

  private

    def disclosure
      Whatsapp.phrase("whatsapp.bot.onboarding.disclosure", portal_name: Whatsapp::PortalLinks.portal_name)
    end

    # Consent under GDPR Art. 6(1)(a) is captured by the tap on "Yes", so the
    # line naming what is consented to has to be the body of the message that
    # carries that button — not an earlier one the citizen may not have read.
    def consent
      I18n.t(
        "whatsapp.bot.onboarding.consent",
        privacy_url: Whatsapp::PortalLinks.privacy_url
      )
    end
end
