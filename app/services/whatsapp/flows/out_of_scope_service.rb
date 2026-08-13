class Whatsapp::Flows::OutOfScopeService < Whatsapp::Flows::BaseService
  # Catalog E33. A friendly boundary and a link, with no handoff to a human —
  # there is no human on this number, and implying otherwise would leave the
  # citizen waiting for an answer that never comes.
  def call
    Whatsapp::Outbound.text(account: account, body: body)
  end

  private

    def body
      Whatsapp.phrase("whatsapp.bot.compliance.out_of_scope", portal_name: Whatsapp::PortalLinks.portal_name,
        help_url: Whatsapp::PortalLinks.help_url)
    end
end
