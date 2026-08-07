class Whatsapp::Flows::IdleGreetingService < ApplicationService
  # What a linked citizen gets for "Hallo" with nothing in progress. It replaced
  # the help text, which listed four things in prose and gave no way to start
  # any of them.
  #
  # Three buttons is the whole budget WhatsApp allows, so the rest of what the
  # bot can do is named as typeable rather than shown — a fourth capability
  # would otherwise have to push one of these off the message.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    @conversation.reset_flow!

    Whatsapp::Outbound.buttons(
      account: @conversation.whatsapp_account,
      body: body,
      buttons: buttons
    )
  end

  private

    def body
      [::Whatsapp.welcome_greeting, I18n.t("whatsapp.bot.free_text_hint")].join("\n\n")
    end

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :submit_proposal, label_key: "whatsapp.bot.buttons.submit_proposal"
        ),
        Whatsapp::FlowActions.button(
          action: :discover, label_key: "whatsapp.bot.buttons.show_projekts"
        ),
        Whatsapp::FlowActions.button(
          action: :my_contributions, label_key: "whatsapp.bot.buttons.my_contributions"
        )
      ]
    end
end
