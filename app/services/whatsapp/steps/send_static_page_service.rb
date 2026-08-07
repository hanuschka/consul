class Whatsapp::Steps::SendStaticPageService < ApplicationService
  # The portal's own help and contact pages, by slug. Admins already write and
  # translate them, so the bot links rather than keeping a second copy of the
  # same answers that would drift from the site's.
  SLUGS_BY_KEY = {
    help: %w[hilfe help],
    contact: %w[kontakt contact]
  }.freeze

  def initialize(conversation:, page_key:)
    @conversation = conversation
    @page_key = page_key
  end

  def call
    return send_missing if page.blank?

    Whatsapp::Steps::SendLinkButtonService.call(
      conversation: @conversation,
      body: I18n.t("whatsapp.bot.menu.#{@page_key}.body"),
      url: page_url,
      button_label: I18n.t("whatsapp.bot.menu.#{@page_key}.button")
    )
  end

  private

    def page
      return @page if defined?(@page)

      @page =
        SiteCustomization::Page
          .where(status: "published", slug: SLUGS_BY_KEY.fetch(@page_key, []))
          .first
    end

    def page_url
      Rails.application.routes.url_helpers.page_url(id: page.slug, **UrlOptions.default.to_h)
    end

    # A portal that never created the page should not leave the citizen with a
    # broken row, so the reply says so and offers the way back.
    def send_missing
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.menu.#{@page_key}.missing"),
        actions: [:menu]
      )
    end
end
