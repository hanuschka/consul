module Adm::Concerns::AreaManagerForSection
  extend ActiveSupport::Concern

  AREA_MANAGER_PREDICATES = {
    "projekts"           => :projekt_manager?,
    "ideas"              => :idea_manager?,
    "deficiency_reports" => :deficiency_report_manager?,
    "landing_pages"      => :landing_page_manager?,
    "moderation"         => :moderator?,
    "valuation"          => :valuator?,
    "officing"           => :officing_manager?
  }.freeze

  private

    # Returns true when the current @user is the area-level manager
    # for the given section name (one of Adm::Section::NAMES).
    # Unknown sections / blank section / no user → false.
    def area_manager_for?(section)
      return false unless @user
      return false if section.blank?

      predicate = AREA_MANAGER_PREDICATES[section.to_s]
      return false unless predicate

      @user.public_send(predicate)
    end
end
