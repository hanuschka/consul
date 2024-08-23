class DeficiencyReportManagement::MenuComponent < ApplicationComponent
  include LinkListHelper
  delegate :current_user, :can?, :link_list, to: :helpers

  def initialize
  end

  def links
    [
      deficiency_reports_link,
      officers_link,
      categories_link,
      statuses_link,
      settings_link,
      official_answer_templates_link,
      areas_link
    ].compact
  end

  private

    def deficiency_reports_link
      return unless can?(:index, DeficiencyReport)

      [
        t("custom.admin.menu.deficiency_reports.list"),
        deficiency_report_management_deficiency_reports_path,
        controller_name == "deficiency_reports"
      ]
    end

    def officers_link
      return unless can?(:index, DeficiencyReport::Officer)

      [
        t("custom.admin.menu.deficiency_reports.officers"),
        deficiency_report_management_officers_path,
        controller_name == "officers"
      ]
    end

    def categories_link
      return unless can?(:index, DeficiencyReport::Category)

      [
        t("custom.admin.menu.deficiency_reports.categories"),
        deficiency_report_management_categories_path,
        controller_name == "categories"
      ]
    end

    def statuses_link
      return unless can?(:index, DeficiencyReport::Status)

      [
        t("custom.admin.menu.deficiency_reports.statuses"),
        deficiency_report_management_statuses_path,
        controller_name == "statuses"
      ]
    end

    def settings_link
      return unless can?(:manage, DeficiencyReport)

      [
        t("custom.admin.menu.deficiency_reports.settings"),
        deficiency_report_management_settings_path,
        controller_name == "settings"
      ]
    end

    def official_answer_templates_link
      return unless can?(:index, DeficiencyReport::OfficialAnswerTemplate)

      [
        t("custom.admin.menu.deficiency_reports.official_answer_templates"),
        deficiency_report_management_official_answer_templates_path,
        controller_name == "official_answer_templates"
      ]
    end

    def areas_link
      return unless can?(:index, DeficiencyReport::Area)

      [
        t("custom.admin.menu.deficiency_reports.areas"),
        deficiency_report_management_areas_path,
        controller_name == "areas"
      ]
    end
end
