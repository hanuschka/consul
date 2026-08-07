class Whatsapp::Flows::LinkErrorService < ApplicationService
  # Catalog A4-A6. Three ways a login attempt can fail, each with its own way
  # out: register, retry, or switch the account this number points at. A shared
  # "that didn't work" would leave the citizen with nothing to do next, which is
  # the whole reason the catalog splits them.
  REASONS = %w[no_account expired already_linked].freeze

  def initialize(conversation:, reason:)
    @conversation = conversation
    @reason = REASONS.include?(reason.to_s) ? reason.to_s : "expired"
  end

  def call
    return Whatsapp::Outbound.text(account: account, body: body) if buttons.empty?

    Whatsapp::Outbound.buttons(account: account, body: body, buttons: buttons)
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def body
      I18n.t(
        "whatsapp.bot.onboarding.#{@reason}",
        register_url: Whatsapp::PortalLinks.register_url
      )
    end

    # No account is the one branch with nothing to offer in the chat: the way on
    # is registering on the portal, which the copy links to. The other two both
    # end in another login attempt, so both carry the same retry pill.
    def buttons
      return [] if @reason == "no_account"

      [
        Whatsapp::FlowActions.button(
          action: :link_retry, label_key: "whatsapp.bot.buttons.login_again"
        )
      ]
    end
end
