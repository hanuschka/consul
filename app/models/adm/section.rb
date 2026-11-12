module Adm
  module Section
    NAMES = %w[
      ideas deficiency_reports municipal_plans offers projekts
      moderation valuation landing_pages officing
    ].freeze

    ICONS = {
      "administration" => { material: "admin_panel_settings", font_awesome: "fa-user-shield" },
      "projekts" => { material: "folder", font_awesome: "fa-folder" },
      "landing_pages" => { material: "web", font_awesome: "fa-globe" },
      "moderation" => { material: "shield", font_awesome: "fa-shield-alt" },
      "deficiency_reports" => { material: "report_problem", font_awesome: "fa-exclamation-triangle" },
      "municipal_plans" => { material: "assignment", font_awesome: "fa-clipboard-list" },
      "offers" => { material: "volunteer_activism", font_awesome: "fa-hands-helping" },
      "ideas" => { material: "lightbulb", font_awesome: "fa-lightbulb" },
      "valuation" => { material: "account_balance_wallet", font_awesome: "fa-wallet" },
      "officing" => { material: "how_to_vote", font_awesome: "fa-vote-yea" }
    }.freeze

    MANAGER_PREDICATES = {
      "projekts"           => :projekt_manager?,
      "ideas"              => :idea_manager?,
      "deficiency_reports" => :deficiency_report_manager?,
      "municipal_plans"    => :administrator?,
      "offers"             => :administrator?,
      "landing_pages"      => :landing_page_manager?,
      "moderation"         => :moderator?,
      "valuation"          => :valuator?,
      "officing"           => :officing_manager?
    }.freeze
  end
end
