class Whatsapp::Flows::OnboardingGreetingService < Whatsapp::Flows::BaseService
  # The new-number protocol: the very first message a number ever gets, plus
  # the standalone bot disclosure for a number greeted before the disclosure
  # existed.
  #
  # The "welcome back" greeting that used to sit here is gone with the linking
  # question it asked. A number that wrote in again was answered with the same
  # decision it had already declined, before it could say what it wanted — see
  # ProcessMessageService, which no longer holds an unlinked gate at all.

  def self.first_contact(conversation:)
    new(conversation: conversation).first_contact
  end

  def self.disclose(conversation:)
    new(conversation: conversation).disclose
  end

  # Catalog A1. Four messages, in this order and as separate bubbles rather
  # than one: the AI disclosure is a platform obligation and has to stand on
  # its own, the consent line has to be readable rather than folded into a
  # longer body, and burying either is what makes them easy to miss.
  #
  # The portal's own greeting heads them. It is what the admin wrote for this
  # moment — the /adm field says so — and saying it here is what lets the main
  # menu stop repeating the introduction to citizens who have already read it.
  #
  # It ends in the menu, not in a question about linking. What a citizen can do
  # here comes first; linking is asked for later, by whichever action turns out
  # to need it (CON-2971). The consent line stays, as a statement rather than a
  # decision — nothing is tied to an account yet, and LinkRequestService puts
  # it back in front of anyone about to do so.
  def first_contact
    Whatsapp::Send.text(account: account, body: ::Whatsapp.onboarding_greeting)
    Whatsapp::Send.text(account: account, body: disclosure)
    Whatsapp::Send.text(account: account, body: consent)

    account.mark_ai_disclosed!

    Whatsapp::Flows::MainMenuService.onboarding(conversation: @conversation)
  end

  # Catalog E31. The bot has to say it is a bot, once per number ever —
  # first_contact carries it for everyone new, so this is only for a number
  # greeted before the disclosure existed. It used to repeat on every new
  # 24-hour service window, which meant a regular reads the same sentence
  # every day and stops seeing it — the thing the rule exists to prevent.
  #
  # Sent as its own message rather than prepended to whatever answer follows.
  # A disclosure buried above three paragraphs of something else is just as
  # invisible.
  def disclose
    Whatsapp::Send.text(
      account: account,
      body: Whatsapp.phrase(
        "whatsapp.bot.compliance.disclosure", portal_name: Whatsapp::PortalLinks.portal_name
      )
    )

    account.mark_ai_disclosed!
  end

  private

    def disclosure
      Whatsapp.phrase("whatsapp.bot.onboarding.disclosure", portal_name: Whatsapp::PortalLinks.portal_name)
    end

    # Consent under GDPR Art. 6(1)(a). Its own message rather than the body of
    # a button: there is no decision to attach it to here any more, and a
    # citizen who only ever browses never reaches one. Said again by
    # LinkRequestService, which is where a number actually gets tied to an
    # account.
    def consent
      I18n.t(
        "whatsapp.bot.onboarding.consent",
        privacy_url: Whatsapp::PortalLinks.privacy_url
      )
    end
end
