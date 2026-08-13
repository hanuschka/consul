class Whatsapp::Flows::LinkOutcomeService < Whatsapp::Flows::BaseService
  # Every answer a login attempt can end in — linked, declined, or one of the
  # catalog's failures. One service because the three are the same moment in
  # the conversation: the citizen has just decided about linking, and the
  # link-reply job and the flow pills all land here.
  #
  # A4-A6: four ways a login attempt can fail, each with its own way out —
  # register, retry, or switch the account this number points at. A shared
  # "that didn't work" would leave the citizen with nothing to do next, which
  # is the whole reason the catalog splits them.
  #
  # already_linked and number_taken are the two directions of the same clash
  # and need opposite answers: the citizen whose account already holds another
  # number has nothing to switch here, while the number that belongs to
  # someone else can only be freed from this chat.
  ERROR_REASONS = %w[no_account expired already_linked number_taken].freeze

  def self.confirmed(conversation:)
    new(conversation: conversation).confirmed
  end

  def self.declined(conversation:)
    new(conversation: conversation).declined
  end

  def self.error(conversation:, reason:)
    new(conversation: conversation).error(reason)
  end

  # Catalog A1 tail. The success confirmation flows straight into the
  # discovery offer rather than ending the conversation: the moment someone
  # has just linked is the one moment they are certain to be looking at the
  # chat.
  def confirmed
    @conversation.reset_flow!

    Whatsapp::Send.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.linked")
    )

    Whatsapp::Send.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.discovery_offer"),
      buttons: discovery_buttons
    )
  end

  # Catalog A3. Declining is not commented on negatively — what is lost is
  # stated plainly and the discovery offer still stands, because someone who
  # will not link may still want to read the portal.
  def declined
    @conversation.reset_flow!

    Whatsapp::Send.buttons(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.onboarding.declined"),
      buttons: declined_buttons
    )
  end

  def error(reason)
    @reason = ERROR_REASONS.include?(reason.to_s) ? reason.to_s : "expired"

    return Whatsapp::Send.text(account: account, body: error_body) if error_buttons.empty?

    Whatsapp::Send.buttons(account: account, body: error_body, buttons: error_buttons)
  end

  private

    def discovery_buttons
      [
        Whatsapp::FlowActions.button(
          action: :discover, label_key: "whatsapp.bot.buttons.show_projekts"
        ),
        Whatsapp::FlowActions.button(
          action: :dismiss, label_key: "whatsapp.bot.buttons.no_thanks"
        )
      ]
    end

    def declined_buttons
      [
        Whatsapp::FlowActions.button(
          action: :discover_public, label_key: "whatsapp.bot.buttons.show_current_projekts"
        ),
        Whatsapp::FlowActions.button(
          action: :dismiss, label_key: "whatsapp.bot.buttons.got_it"
        )
      ]
    end

    def error_body
      Whatsapp.phrase("whatsapp.bot.onboarding.#{@reason}", register_url: Whatsapp::PortalLinks.register_url)
    end

    # No account is the one branch with nothing to offer in the chat: the way
    # on is registering on the portal, which the copy links to. A number that
    # belongs to someone else is the one branch a retry cannot fix — the pill
    # releases it first, which is why it is the only producer of link_switch.
    def error_buttons
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
