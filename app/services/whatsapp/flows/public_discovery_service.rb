class Whatsapp::Flows::PublicDiscoveryService < ApplicationService
  # Catalog A3's "Show current projects", for a number that declined linking.
  #
  # It used to be a plain digest of names and links on the reasoning that
  # without an account there is nothing to tap through to. Guest phases make
  # that false: a phase set to guest participation accepts a submission from
  # anyone, so where one is open this is the interactive list after all — and
  # the only way to reach guest participation without scanning a QR code.
  MAX_SHOWN = 5

  def initialize(conversation:)
    @conversation = conversation
  end

  # One projekt is a projekt the bot is pointing at, so it gets the card. Several
  # are a digest, and five cards would be five notifications for a question that
  # asked for an overview.
  def call
    return send_guest_phases if guest_phases.any?
    return send_card if projekts.one?

    Whatsapp::Outbound.text(account: @conversation.whatsapp_account, body: body)
  end

  private

    def guest_phases
      @guest_phases ||= Whatsapp::EligiblePhasesQuery.guest_open
    end

    def send_guest_phases
      Whatsapp::Flows::SendListService.call(
        conversation: @conversation,
        rows: Whatsapp::PhaseListRows.build(guest_phases),
        body: I18n.t("whatsapp.bot.discovery.guest_body"),
        button_label: I18n.t("whatsapp.bot.discovery.button"),
        empty_body: I18n.t("whatsapp.bot.discovery.empty")
      )
    end

    def send_card
      Whatsapp::Flows::SendProjektCardService.call(
        conversation: @conversation, projekt: projekts.first
      )
    end

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
