module Adm::SectionsHelper
  # Static view data for admin sections: icon + root path per section key.
  # Visibility is decided separately by Adm::SectionVisibility.
  def adm_sections
    paths = {
      "administration" => adm_root_path,
      "projekts" => adm_projekts_root_path,
      "landing_pages" => adm_landing_pages_root_path,
      "moderation" => adm_moderation_root_path,
      "deficiency_reports" => adm_deficiency_reports_root_path,
      "ideas" => adm_ideas_root_path,
      "valuation" => adm_valuation_root_path,
      "officing" => adm_officing_root_path
    }

    paths.to_h { |key, path| [key, { icon: Adm::Section::ICONS[key][:material], path: path }] }
  end
end
