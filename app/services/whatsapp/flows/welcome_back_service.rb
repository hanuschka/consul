class Whatsapp::Flows::WelcomeBackService < ApplicationService
  # For a number that has written before and is still not linked — someone who
  # tapped "Later", or whose login link went cold. They used to be handed
  # another login link on every message, which answers a question they never
  # re-asked; this puts the question back, with the same two ways out the first
  # contact offered.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    @conversation.update!(step: "awaiting_link_decision")

    Whatsapp::Outbound.buttons(
      account: @conversation.whatsapp_account,
      body: body,
      buttons: buttons
    )
  end

  private

    def buttons
      link_buttons = [
        Whatsapp::FlowActions.button(
          action: :link_yes, label_key: "whatsapp.bot.buttons.link_yes"
        ),
        Whatsapp::FlowActions.button(
          action: :link_later, label_key: "whatsapp.bot.buttons.link_later"
        )
      ]

      return link_buttons if guest_phases.empty?

      link_buttons + [
        Whatsapp::FlowActions.button(
          action: :submit_proposal, label_key: "whatsapp.bot.buttons.submit_proposal"
        )
      ]
    end

    # Asked rather than assumed: on a portal with no guest phase open the third
    # button would lead straight to "nothing is open right now", which is a
    # worse answer than not offering it.
    def guest_phases
      @guest_phases ||= Whatsapp::EligiblePhasesQuery.guest_open
    end

    # The linking question is the same either way; only the sentence under it
    # changes, because someone who can take part without an account should be
    # told so rather than left to tap and find out.
    def body
      return I18n.t("whatsapp.bot.onboarding.welcome_back") if guest_phases.empty?

      [
        I18n.t("whatsapp.bot.onboarding.welcome_back"),
        I18n.t("whatsapp.bot.onboarding.welcome_back_guest_hint")
      ].join("\n\n")
    end
end
