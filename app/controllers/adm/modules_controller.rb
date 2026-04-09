module Adm
  class ModulesController < Adm::BaseController
    MODULE_SETTINGS = %w[
      process.deficiency_reports
      extended_feature.general.enable_projekt_events_page
      process.ideas
      process.projekts
      extended_feature.general.enable_investments_overview
      extended_feature.general.enable_polls_overview
      extended_feature.general.enable_proposals_overview
    ].freeze

    def show
      authorize [:adm, :modules]
      @module_settings = MODULE_SETTINGS.filter_map { |key| Setting.find_by(key: key) }

      @breadcrumbs = [
        { name: t("adm.modules.show.title"), icon: "widgets" }
      ]
    end
  end
end
