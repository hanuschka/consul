module Adm
  class OverviewPagesController < Adm::BaseController
    NAVIGATION_PHASES = %w[all underway ongoing upcoming expired individual_list drafts].freeze
    FOOTER_PHASES     = %w[all underway ongoing upcoming expired individual_list].freeze

    def projekt
      authorize [:adm, Setting], :update?
      @master_setting = Setting.find_by(key: "process.projekts")
      @navigation_settings = NAVIGATION_PHASES.map { |phase|
        Setting.find_by(key: "extended_feature.projekts_overview_page_navigation.show_index_order_#{phase}")
      }.compact
      @footer_settings = FOOTER_PHASES.map { |phase|
        Setting.find_by(key: "extended_feature.projekts_overview_page_footer.show_in_index_order_#{phase}")
      }.compact
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.overview_pages") }
      ]
    end

    def others
      authorize [:adm, Setting], :update?
      @overview_settings = [
        Setting.find_by(key: "extended_feature.general.enable_projekt_events_page"),
        Setting.find_by(key: "extended_feature.general.enable_investments_overview"),
        Setting.find_by(key: "process.polls"),
        Setting.find_by(key: "process.proposals"),
        Setting.find_by(key: "extended_feature.general.users_overview_page")
      ].compact
      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.overview_pages") }
      ]
    end
  end
end
