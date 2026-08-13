class Whatsapp::Flows::WelcomeBackService < Whatsapp::Flows::BaseService
  # For a number that has written before and is still not linked — someone who
  # tapped "Later", or whose login link went cold. They used to be handed
  # another login link on every message, which answers a question they never
  # re-asked; this puts the question back, with the same two ways out the first
  # contact offered.
  def call
    @conversation.update!(step: "awaiting_link_decision")

    Whatsapp::Outbound.buttons(
      account: account,
      body: body,
      buttons: buttons
    )
  end

  private

    def buttons
      link_buttons = Whatsapp::FlowActions.link_decision_buttons

      return link_buttons if !guest_participation_open?

      link_buttons + [
        Whatsapp::FlowActions.button(
          action: :submit_proposal, label_key: "whatsapp.bot.buttons.submit_proposal"
        )
      ]
    end

    # Asked rather than assumed: on a portal with no guest phase open the third
    # button would lead straight to "nothing is open right now", which is a
    # worse answer than not offering it.
    #
    # This runs for every message from every number that declined linking, so it
    # asks the existence question rather than the listing one — the phases
    # themselves are never read here.
    def guest_participation_open?
      return @guest_participation_open if defined?(@guest_participation_open)

      @guest_participation_open = Whatsapp::EligiblePhasesQuery.guest_open?
    end

    # The linking question is the same either way; only the sentence under it
    # changes, because someone who can take part without an account should be
    # told so rather than left to tap and find out.
    def body
      greeting = Whatsapp.phrase("whatsapp.bot.onboarding.welcome_back")

      return greeting if !guest_participation_open?

      [greeting, Whatsapp.phrase("whatsapp.bot.onboarding.welcome_back_guest_hint")].join("\n\n")
    end
end
