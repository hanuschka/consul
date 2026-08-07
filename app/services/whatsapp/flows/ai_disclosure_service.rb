class Whatsapp::Flows::AiDisclosureService < ApplicationService
  # Catalog E31. WhatsApp requires the bot to say it is a bot at the start of
  # every new session, and a session here is the 24-hour service window: outside
  # it the bot cannot send freeform messages at all, so a citizen writing in
  # after a day away is starting a new conversation whether or not they think of
  # it that way.
  #
  # Sent as its own message rather than prepended to whatever answer follows. A
  # disclosure buried above three paragraphs of something else is the one thing
  # this rule exists to prevent.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.text(account: @conversation.whatsapp_account, body: body)
  end

  private

    def body
      I18n.t(
        "whatsapp.bot.compliance.disclosure",
        portal_name: Whatsapp::PortalLinks.portal_name
      )
    end
end
