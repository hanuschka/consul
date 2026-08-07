class Whatsapp::Flows::LinkErrorService < ApplicationService
  # Catalog A4-A6. Four ways a login attempt can fail, each with its own way
  # out: register, retry, or switch the account this number points at. A shared
  # "that didn't work" would leave the citizen with nothing to do next, which is
  # the whole reason the catalog splits them.
  #
  # already_linked and number_taken are the two directions of the same clash and
  # need opposite answers: the citizen whose account already holds another
  # number has nothing to switch here, while the number that belongs to someone
  # else can only be freed from this chat.
  REASONS = %w[no_account expired already_linked number_taken].freeze

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
    # is registering on the portal, which the copy links to. A number that
    # belongs to someone else is the one branch a retry cannot fix — the pill
    # releases it first, which is why it is the only producer of link_switch.
    def buttons
      return [] if @reason == "no_account"
      return [switch_button] if @reason == "number_taken"

      [
        Whatsapp::FlowActions.button(
          action: :link_retry, label_key: "whatsapp.bot.buttons.login_again"
        )
      ]
    end

    def switch_button
      Whatsapp::FlowActions.button(
        action: :link_switch, label_key: "whatsapp.bot.buttons.link_switch"
      )
    end
end
