class Adm::IconRailComponent < ApplicationComponent
  def initialize(current_user:)
    @current_user = current_user
  end

  private

    def items
      Adm::NavigationSections.for(user: @current_user, url_helpers: helpers)
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
