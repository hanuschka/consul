class Whatsapp::Flows::OnboardingGreetingService < Whatsapp::Flows::BaseService
  # The new-number protocol: the two greetings an unlinked number can get —
  # the very first message ever, and every visit after a "Later" — plus the
  # standalone bot disclosure for a number greeted before the disclosure
  # existed.

  def self.first_contact(conversation:)
    new(conversation: conversation).first_contact
  end

  def self.welcome_back(conversation:)
    new(conversation: conversation).welcome_back
  end

  def self.disclose(conversation:)
    new(conversation: conversation).disclose
  end

  # Catalog A1. Four messages, in this order and as separate bubbles rather
  # than one: the AI disclosure is a platform obligation and has to stand on
  # its own, the consent line has to be readable next to the button that
  # accepts it, and burying either inside a longer body is what makes them
  # easy to miss.
  #
  # The portal's own greeting heads them. It is what the admin wrote for this
  # moment — the /adm field says so — and saying it here is what lets the main
  # menu stop repeating the introduction to citizens who have already read it.
  def first_contact
    Whatsapp::Outbound.text(account: account, body: ::Whatsapp.onboarding_greeting)
    Whatsapp::Outbound.text(account: account, body: disclosure)
    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.link_question")
    )

    account.mark_ai_disclosed!
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_LINK_DECISION)

    Whatsapp::Outbound.buttons(
      account: account,
      body: consent,
      buttons: Whatsapp::FlowActions.link_decision_buttons
    )
  end

  # For a number that has written before and is still not linked — someone who
  # tapped "Later", or whose login link went cold. They used to be handed
  # another login link on every message, which answers a question they never
  # re-asked; this puts the question back, with the same two ways out the
  # first contact offered.
  def welcome_back
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_LINK_DECISION)

    Whatsapp::Outbound.buttons(
      account: account,
      body: welcome_back_body,
      buttons: welcome_back_buttons
    )
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
    Whatsapp::Outbound.text(
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

    # Consent under GDPR Art. 6(1)(a) is captured by the tap on "Yes", so the
    # line naming what is consented to has to be the body of the message that
    # carries that button — not an earlier one the citizen may not have read.
    def consent
      I18n.t(
        "whatsapp.bot.onboarding.consent",
        privacy_url: Whatsapp::PortalLinks.privacy_url
      )
    end

    def welcome_back_buttons
      link_buttons = Whatsapp::FlowActions.link_decision_buttons

      return link_buttons if !guest_participation_open?

      link_buttons + [
        Whatsapp::FlowActions.button(
          action: :submit_proposal, label_key: "whatsapp.bot.buttons.submit_proposal"
        )
      ]
    end

    # Asked rather than assumed: on a portal with no guest phase open the
    # third button would lead straight to "nothing is open right now", which
    # is a worse answer than not offering it.
    #
    # This runs for every message from every number that declined linking, so
    # it asks the existence question rather than the listing one — the phases
    # themselves are never read here.
    def guest_participation_open?
      return @guest_participation_open if defined?(@guest_participation_open)

      @guest_participation_open = Whatsapp::EligiblePhasesQuery.guest_open?
    end

    # The linking question is the same either way; only the sentence under it
    # changes, because someone who can take part without an account should be
    # told so rather than left to tap and find out.
    def welcome_back_body
      greeting = Whatsapp.phrase("whatsapp.bot.onboarding.welcome_back")

      return greeting if !guest_participation_open?

      [greeting, Whatsapp.phrase("whatsapp.bot.onboarding.welcome_back_guest_hint")].join("\n\n")
    end
end
