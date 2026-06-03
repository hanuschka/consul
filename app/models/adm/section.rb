module Adm
  module Section
    NAMES = %w[ideas deficiency_reports projekts moderation valuation landing_pages officing].freeze

    MANAGER_PREDICATES = {
      "projekts"           => :projekt_manager?,
      "ideas"              => :idea_manager?,
      "deficiency_reports" => :deficiency_report_manager?,
      "landing_pages"      => :landing_page_manager?,
      "moderation"         => :moderator?,
      "valuation"          => :valuator?,
      "officing"           => :officing_manager?
    }.freeze
  end
end
