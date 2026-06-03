module Adm::SectionsHelper
  # Static view data for admin sections: icon + root path per section key.
  # Visibility is decided separately by Adm::SectionVisibility.
  def adm_sections
    {
      "administration"     => { icon: "admin_panel_settings",   path: adm_root_path },
      "projekts"           => { icon: "folder",                 path: adm_projekts_root_path },
      "landing_pages"      => { icon: "web",                    path: adm_landing_pages_root_path },
      "moderation"         => { icon: "shield",                 path: adm_moderation_root_path },
      "deficiency_reports" => { icon: "report_problem",         path: adm_deficiency_reports_root_path },
      "ideas"              => { icon: "lightbulb",              path: adm_ideas_root_path },
      "valuation"          => { icon: "account_balance_wallet", path: adm_valuation_root_path },
      "officing"           => { icon: "how_to_vote",            path: adm_officing_root_path }
    }
  end
end
