module Adm
  class ModulesController < Adm::BaseController
    # Map all tabs to their module setting keys
    TAB_MODULE_SETTINGS = {
      "ideas" => "process.ideas",
      "projekts" => "process.projekts",
      "deficiency_reports" => "process.deficiency_reports",
      "events" => "extended_feature.general.enable_projekt_events_page",
      "investments" => "extended_feature.general.enable_investments_overview",
      "polls" => "extended_feature.general.enable_polls_overview",
      "proposals" => "extended_feature.general.enable_proposals_overview"
    }.freeze

    # Tabs with section settings (intro text, notice)
    SECTION_TABS = SectionSetting::SECTIONS.freeze

    # Tabs that only have a module toggle
    EXTRA_TABS = %w[events investments polls proposals].freeze

    TABS = (SECTION_TABS + EXTRA_TABS).freeze

    helper_method :section_label

    def show
      authorize [:adm, :modules]

      @current_tab = params[:tab].in?(TABS) ? params[:tab] : TABS.first

      setting_key = TAB_MODULE_SETTINGS[@current_tab]
      @module_settings = setting_key ? [Setting.find_by(key: setting_key)].compact : []
      @section_setting = @current_tab.in?(SECTION_TABS) ? SectionSetting.for_section(@current_tab) : nil

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
        setting_key = TAB_MODULE_SETTINGS[@current_tab]
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
