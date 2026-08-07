class Whatsapp::Flows::PublicDiscoveryService < ApplicationService
  # Catalog A3's "Show current projects", for a number that declined linking.
  # Deliberately not the same reply as the linked one: without an account there
  # is nothing to tap through to, so this is a plain digest of names and links
  # rather than an interactive list that would promise participation.
  MAX_SHOWN = 5

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.text(account: @conversation.whatsapp_account, body: body)
  end

  private

    def body
      return I18n.t("whatsapp.bot.discovery.empty") if projekts.empty?

      [I18n.t("whatsapp.bot.discovery.public_intro"), entries, more_line].compact_blank.join("\n\n")
    end

    def projekts
      @projekts ||= Whatsapp::BrowsableProjektsQuery.call
    end

    def entries
      projekts.first(MAX_SHOWN).map do |projekt|
        I18n.t(
          "whatsapp.bot.discovery.entry",
          title: Whatsapp::ProjektLink.title(projekt),
          url: Whatsapp::ProjektLink.url(projekt)
        )
      end.join("\n\n")
    end

    # Truncation is stated rather than silent: a citizen who sees five names has
    # no way to tell whether that is all of them.
    def more_line
      remaining = projekts.size - MAX_SHOWN

      return if remaining < 1

      I18n.t("whatsapp.bot.discovery.more", count: remaining, url: Whatsapp::PortalLinks.root_url)
    end
end
