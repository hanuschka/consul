class Adm::IconRailComponent < ApplicationComponent
  def initialize(current_user:)
    @current_user = current_user
  end

  private

    def items
      list = []

      if @current_user.administrator?
        list << { icon: "admin_panel_settings", path: helpers.adm_root_path, key: "administration", section: "Adm" }
      end

      if @current_user.administrator? || @current_user.projekt_manager?
        list << { icon: "folder", path: helpers.adm_projekts_root_path, key: "projekts", section: "Adm::Projekts" }
      end

      if @current_user.administrator? || @current_user.landing_page_manager?
        list << { icon: "web", path: helpers.adm_landing_pages_root_path, key: "landing_pages", section: "Adm::LandingPages" }
      end

      if @current_user.administrator? || @current_user.moderator?
        list << { icon: "shield", path: helpers.adm_moderation_root_path, key: "moderation", section: "Adm::Moderation" }
      end

      if Adm::DeficiencyReports::DeficiencyReportPolicy.new(@current_user, nil).index?
        list << { icon: "report_problem", path: helpers.adm_deficiency_reports_root_path, key: "deficiency_reports", section: "Adm::DeficiencyReports" }
      end

      if Adm::Ideas::IdeaPolicy.new(@current_user, nil).index?
        list << { icon: "lightbulb", path: helpers.adm_ideas_root_path, key: "ideas", section: "Adm::Ideas" }
      end

      if helpers.feature?(:budgets) && (@current_user.administrator? || @current_user.valuator?)
        list << { icon: "account_balance_wallet", path: helpers.adm_valuation_root_path, key: "valuation", section: "Adm::Valuation" }
      end

      if Adm::Officing::BasePolicy.new(@current_user, nil).index?
        list << { icon: "how_to_vote", path: helpers.adm_officing_root_path, key: "officing", section: "Adm::Officing" }
      end

      list
    end

    CONTROLLER_SECTION_MAP = {
      "Adm::ModeratorsController" => "Adm::Moderation",
      "Adm::ValuatorsController" => "Adm::Valuation",
      "Adm::OfficingManagersController" => "Adm::Officing"
    }.freeze

    def active?(item)
      section = resolved_section
      if item[:section] == "Adm"
        section == "Adm"
      else
        section&.start_with?(item[:section])
      end
    end

    def resolved_section
      CONTROLLER_SECTION_MAP[controller.class.name] || controller.class.module_parent_name || "Adm"
    end
end
