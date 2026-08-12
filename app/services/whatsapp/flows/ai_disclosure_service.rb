class Whatsapp::Flows::AiDisclosureService < Whatsapp::Flows::BaseService
  # Catalog E31. The bot has to say it is a bot, once, on a citizen's very first
  # message. It used to repeat on every new 24-hour service window, which meant
  # a regular reads the same sentence every day and stops seeing it — the thing
  # the rule exists to prevent.
  #
  # Sent as its own message rather than prepended to whatever answer follows. A
  # disclosure buried above three paragraphs of something else is just as
  # invisible.
  def call
    Whatsapp::Outbound.text(account: account, body: body)

    account.mark_ai_disclosed!
  end

  private

    def body
      Whatsapp.phrase("whatsapp.bot.compliance.disclosure", portal_name: Whatsapp::PortalLinks.portal_name)
    end
end
