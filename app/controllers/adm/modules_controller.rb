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

    # Map sections to their module setting keys
    SECTION_MODULE_SETTINGS = {
      "ideas" => "process.ideas",
      "projekts" => "process.projekts",
      "deficiency_reports" => "process.deficiency_reports"
    }.freeze

    # Module settings not tied to a section (shown in "Allgemein" tab)
    GENERAL_MODULE_SETTINGS = %w[
      extended_feature.general.enable_projekt_events_page
      extended_feature.general.enable_investments_overview
      extended_feature.general.enable_polls_overview
      extended_feature.general.enable_proposals_overview
    ].freeze

    TABS = (SectionSetting::SECTIONS + ["general"]).freeze

    helper_method :section_label

    def show
      authorize [:adm, :modules]

      @current_tab = params[:tab].in?(TABS) ? params[:tab] : TABS.first

      if @current_tab == "general"
        @module_settings = GENERAL_MODULE_SETTINGS.filter_map { |key| Setting.find_by(key: key) }
        @section_setting = nil
      else
        setting_key = SECTION_MODULE_SETTINGS[@current_tab]
        @module_settings = setting_key ? [Setting.find_by(key: setting_key)].compact : []
        @section_setting = SectionSetting.for_section(@current_tab)
      end

      @breadcrumbs = [
        { name: t("adm.modules.show.title"), icon: "widgets" }
      ]
    end

    def update
      authorize [:adm, :modules]

      @current_tab = params[:tab].in?(SectionSetting::SECTIONS) ? params[:tab] : SectionSetting::SECTIONS.first
      @section_setting = SectionSetting.for_section(@current_tab)
      @section_setting.author = current_user

      if @section_setting.update(section_setting_params)
        redirect_to adm_modules_path(tab: @current_tab),
                    notice: t("adm.section_settings.flash.updated")
      else
        setting_key = SECTION_MODULE_SETTINGS[@current_tab]
        @module_settings = setting_key ? [Setting.find_by(key: setting_key)].compact : []
        @breadcrumbs = [{ name: t("adm.modules.show.title"), icon: "widgets" }]
        render :show, status: :unprocessable_entity
      end
    end

    private

      def section_setting_params
        params.require(:section_setting).permit(:intro_text, :notice_message, :notice_active)
      end

      def section_label(section)
        t("adm.section_settings.sections.#{section}")
      end
  end
end
