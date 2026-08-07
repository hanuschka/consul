class Whatsapp::Flows::FirstContactService < ApplicationService
  # Catalog A1. Three messages, in this order and as three separate bubbles
  # rather than one: the AI disclosure is a platform obligation and has to stand
  # on its own, the consent line has to be readable next to the button that
  # accepts it, and burying either inside a longer body is what makes them easy
  # to miss.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.text(account: account, body: disclosure)
    Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.onboarding.link_question"))

    account.mark_ai_disclosed!
    @conversation.update!(step: "awaiting_link_decision")

    Whatsapp::Outbound.buttons(account: account, body: consent, buttons: buttons)
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def disclosure
      I18n.t(
        "whatsapp.bot.onboarding.disclosure",
        portal_name: Whatsapp::PortalLinks.portal_name
      )
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

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :link_yes, label_key: "whatsapp.bot.buttons.link_yes"
        ),
        Whatsapp::FlowActions.button(
          action: :link_later, label_key: "whatsapp.bot.buttons.link_later"
        )
      ]
    end
end
