module Adm
  class MatomoController < Adm::BaseController
    def show
      authorize [:adm, :matomo]

      @breadcrumbs = [
        { name: t("adm.menu.items.stats"), icon: "bar_chart_4_bars" },
        { name: t("adm.menu.items.stats_subitems.matomo") }
      ]

      base_url     = Rails.application.secrets.matomo_base_url
      site_id      = Rails.application.secrets.matomo_site_id
      access_token = ExternalApiKey.matomo_access_token

      @matomo_configured = base_url.present? && site_id.present? && access_token.present?
      @matomo_iframe_src = build_matomo_iframe_src(base_url, site_id, access_token) if @matomo_configured
    end

    private

      def build_matomo_iframe_src(base_url, site_id, access_token)
        query = URI.encode_www_form(
          module:             "Widgetize",
          action:             "iframe",
          moduleToWidgetize:  "Dashboard",
          actionToWidgetize:  "index",
          idSite:             site_id,
          period:             "week",
          date:               "yesterday",
          token_auth:         access_token
        )

        "https://#{base_url}/index.php?#{query}"
      end
  end
end
