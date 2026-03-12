class Adm::DeficiencyReports::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.deficiency_reports.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.deficiency_reports.menu.items.deficiency_reports"), icon: "report_problem", path: adm_deficiency_reports_root_path },
      { label: t("adm.deficiency_reports.menu.items.officers"), icon: "badge", path: adm_deficiency_reports_officers_path },
      { label: t("adm.deficiency_reports.menu.items.categories"), icon: "category", path: adm_deficiency_reports_categories_path },
      { label: t("adm.deficiency_reports.menu.items.statuses"), icon: "flag", path: adm_deficiency_reports_statuses_path },
      { label: t("adm.deficiency_reports.menu.items.settings"), icon: "settings", path: adm_deficiency_reports_settings_path },
      { label: t("adm.deficiency_reports.menu.items.official_answer_templates"), icon: "description", path: adm_deficiency_reports_official_answer_templates_path },
      { label: t("adm.deficiency_reports.menu.items.districts"), icon: "location_city", path: adm_deficiency_reports_districts_path },
      { label: t("adm.deficiency_reports.menu.items.officer_groups"), icon: "groups", path: adm_deficiency_reports_officer_groups_path },
      { label: t("adm.deficiency_reports.menu.items.stats"), icon: "bar_chart", path: adm_deficiency_reports_stats_path },
      { label: t("adm.deficiency_reports.menu.items.ai_settings"), icon: "smart_toy", path: adm_deficiency_reports_ai_settings_path }
    ]
  end
end
