class Adm::IconRailComponent < ApplicationComponent
  def initialize(current_user:)
    @current_user = current_user
  end

  private

    SECTION_NAMESPACES = {
      "administration"     => "Adm",
      "projekts"           => "Adm::Projekts",
      "landing_pages"      => "Adm::LandingPages",
      "moderation"         => "Adm::Moderation",
      "deficiency_reports" => "Adm::DeficiencyReports",
      "ideas"              => "Adm::Ideas",
      "valuation"          => "Adm::Valuation",
      "officing"           => "Adm::Officing"
    }.freeze

    CONTROLLER_SECTION_MAP = {
      "Adm::ModeratorsController" => "Adm::Moderation",
      "Adm::ValuatorsController" => "Adm::Valuation",
      "Adm::OfficingManagersController" => "Adm::Officing"
    }.freeze

    def items
      sections = helpers.adm_sections
      Adm::SectionVisibility.visible_keys_for(@current_user).map do |key|
        sections[key].merge(key: key)
      end
    end

    def active?(item)
      target_namespace = SECTION_NAMESPACES[item[:key]]
      section = resolved_section
      if target_namespace == "Adm"
        section == "Adm"
      else
        section&.start_with?(target_namespace)
      end
    end

    def resolved_section
      CONTROLLER_SECTION_MAP[controller.class.name] || controller.class.module_parent_name || "Adm"
    end
end
