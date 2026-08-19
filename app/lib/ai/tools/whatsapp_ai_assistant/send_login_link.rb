class Ai::Tools::WhatsappAiAssistant::SendLoginLink < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen a one-time link that connects this number to their portal " \
              "account. Call it when they want to link, when they say they have an account, or " \
              "after a tool has refused something for want of one — never unprompted as the " \
              "answer to a first message. Anyone can read the portal and take part in a phase " \
              "that allows guests without linking, so linking is asked for by what needs it " \
              "rather than at the door. Mention that following the link means accepting the " \
              "privacy policy, whose address comes back here. This sends the message itself."

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_LINK
  end

  def execute
    return already_linked_answer if user.present?

    link_url = ::Whatsapp::Accounts::LinkTokenService.call(account: account)

    return unavailable_error if link_url.blank?

    ::Whatsapp::Send.cta_url(
      account: account,
      body: I18n.t(
        "whatsapp.bot.onboarding.login_prompt",
        privacy_url: ::Whatsapp::PortalLinks.privacy_url
      ),
      button_label: I18n.t("whatsapp.bot.buttons.login"),
      url: link_url
    )

    halt("Sent the login link. The citizen is told when they have followed it, so there is " \
         "nothing to wait for here.")
  end

  private

    def already_linked_answer
      {
        linked: true,
        hint: "This number is already linked, so do not offer to link it. If they want to connect " \
              "a different account, unlink_account has to happen first."
      }
    end

    # The link and the sentence around it stay on the locale copy for one reason: it
    # carries the privacy declaration that following the link accepts, which is not a
    # sentence to be rewritten per message.
    def unavailable_error
      { error: "A login link could not be produced. Tell the citizen it did not work and offer to " \
               "try again shortly." }
    end
end
