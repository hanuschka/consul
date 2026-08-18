class Whatsapp::Flows::BrowseProjektsService < Whatsapp::Flows::BaseService
  # "Projekte durchsuchen" — the portal as it publishes itself, not only what
  # is open for a submission (CON-2967). DiscoveryService keeps the narrower
  # answer, because the moments it serves — right after linking, after a QR
  # code, after a submission — exist to lead into another one, and a projekt
  # whose participation ended leads nowhere from there.
  #
  # Text rather than an interactive list: four groups of five is twenty
  # entries, an interactive body holds about a quarter of what a text body
  # does, and every entry has to carry its own URL (CON-2966) — which a list
  # row has no room for at all. The pills that show a cut group therefore ride
  # on a second message, built from the same groups.
  def self.call(conversation:)
    new(conversation: conversation).call
  end

  def self.category(conversation:, key:)
    new(conversation: conversation, key: key).category
  end

  def initialize(conversation:, key: nil)
    super(conversation: conversation)
    @key = key
  end

  def call
    return send_empty if groups.empty?

    Whatsapp::Send.text(account: account, body: digest_body)

    send_more_offer
  end

  # A pill tapped days later, on a group that has since emptied — a phase
  # closing moves projekts between groups — is answered with the digest as it
  # stands now rather than with nothing.
  def category
    group = Whatsapp::CategorizedProjektsQuery.category(key: @key)

    return call if group.blank?

    Whatsapp::Send.text(account: account, body: category_body(group))
  end

  private

    def groups
      @groups ||= Whatsapp::CategorizedProjektsQuery.call
    end

    def digest_body
      [
        Whatsapp.phrase("whatsapp.bot.discovery.browse.intro"),
        *groups.map { |group| group_block(group) }
      ].join("\n\n")
    end

    def group_block(group)
      [heading(group), entries(group), truncation_line(group)].compact_blank.join("\n\n")
    end

    def category_body(group)
      [heading(group), entries(group), rest_line(group)].compact_blank.join("\n\n")
    end

    # The heading is the portal's own tab wording, read from the tab's own key:
    # a citizen who sees "Laufende Projekte" in the chat and on the website must
    # be looking at the same category, which a second German copy under the
    # bot's keys would not survive.
    #
    # `filters`, not the `orders` namespace Projekts::ProjektListTabsComponent
    # reads — that one holds no index_order_* key in either locale, so the tabs
    # render their own titles from a namespace only the events list fills.
    def heading(group)
      I18n.t("whatsapp.bot.discovery.browse.heading", category: category_title(group[:key]))
    end

    def category_title(key)
      I18n.t("custom.projekts.filters.#{key}")
    end

    def entries(group)
      group[:projekts].map do |projekt|
        I18n.t(
          "whatsapp.bot.discovery.entry",
          title: Whatsapp::ProjektLink.title(projekt),
          url: Whatsapp::ProjektLink.url(projekt)
        )
      end.join("\n\n")
    end

    # Stated rather than silent, for the same reason the public digest states
    # it: five names with nothing after them read as all of them.
    def truncation_line(group)
      remaining = truncated_count(group)

      return if remaining < 1

      I18n.t("whatsapp.bot.discovery.browse.more", count: remaining)
    end

    def truncated_count(group)
      group[:total] - group[:projekts].size
    end

    # The second page ends at the portal's own tab rather than at a third pill:
    # a citizen still reading past fifteen projekts of one category wants the
    # list, not another message.
    def rest_line(group)
      shown = Whatsapp::CategorizedProjektsQuery::MAX_PER_CATEGORY + group[:projekts].size
      remaining = group[:total] - shown

      return if remaining < 1

      I18n.t(
        "whatsapp.bot.discovery.browse.rest",
        count: remaining,
        url: Whatsapp::PortalLinks.projekts_url(filter: group[:key])
      )
    end

    def send_more_offer
      rows = more_rows

      return if rows.empty?

      Whatsapp::Send.list(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.discovery.browse.more_body"),
        button_label: I18n.t("whatsapp.bot.discovery.browse.more_button"),
        rows: rows
      )
    end

    def more_rows
      groups.filter_map do |group|
        remaining = truncated_count(group)

        next if remaining < 1

        {
          id: Whatsapp::FlowActions.id_for(action: :discover_category, param: group[:key]),
          title: category_title(group[:key]),
          description: I18n.t("whatsapp.bot.discovery.browse.more_row", count: remaining)
        }
      end
    end

    # Its own copy rather than the discovery one, which says nothing is open for
    # submissions — true there, and the wrong sentence for a portal that
    # publishes no projekt at all.
    def send_empty
      Whatsapp::Send.text(
        account: account, body: Whatsapp.phrase("whatsapp.bot.discovery.browse.empty")
      )
    end
end
