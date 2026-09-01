class Adm::DeficiencyReports::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    feature = Setting["deficiency_reports.feature_name"].presence
    feature ? t("adm.deficiency_reports.menu.aria_label_feature", feature: feature) : t("adm.deficiency_reports.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.deficiency_reports.menu.items.home"), icon: "home", path: adm_deficiency_reports_root_path, active_pattern: %r{/adm/deficiency_reports/(list|\d+)} },
      (if Adm::DeficiencyReports::OfficerPolicy.new(current_user, nil).index?
         { label: t("adm.deficiency_reports.menu.items.officers"), icon: "badge", path: adm_deficiency_reports_officers_path }
       end),
      (if Adm::DeficiencyReports::SettingPolicy.new(current_user, nil).show?
         { label: t("adm.deficiency_reports.menu.items.settings"), icon: "settings", path: adm_deficiency_reports_settings_path, active_pattern: %r{/adm/deficiency_reports/settings(/dashboard)?\z} }
       end),
      (if Adm::DeficiencyReports::OfficerGroupPolicy.new(current_user, nil).index?
         { label: t("adm.deficiency_reports.menu.items.officer_groups"), icon: "groups", path: adm_deficiency_reports_officer_groups_path }
       end),
      (if Adm::DeficiencyReports::CategoryPolicy.new(current_user, nil).index?
         { label: t("adm.deficiency_reports.menu.items.categories"), icon: "category", path: adm_deficiency_reports_categories_path }
       end),
      (if Adm::DeficiencyReports::StatusPolicy.new(current_user, nil).index?
         { label: t("adm.deficiency_reports.menu.items.statuses"), icon: "flag", path: adm_deficiency_reports_statuses_path }
       end),
      (if Adm::DeficiencyReports::IntakeChannelPolicy.new(current_user, nil).index?
         { label: t("adm.deficiency_reports.menu.items.intake_channels"), icon: "call_received", path: adm_deficiency_reports_intake_channels_path }
       end),
      (if Adm::DeficiencyReports::DistrictPolicy.new(current_user, nil).index?
         { label: t("adm.deficiency_reports.menu.items.districts"), icon: "location_city", path: adm_deficiency_reports_districts_path }
       end),
      (if Adm::DeficiencyReports::OfficialAnswerTemplatePolicy.new(current_user, nil).index?
         { label: t("adm.deficiency_reports.menu.items.official_answer_templates"), icon: "description", path: adm_deficiency_reports_official_answer_templates_path }
       end),
      (if Adm::SiteCustomization::EmailTemplatePolicy.new(current_user, sample_email_template).index?
         { label: t("adm.deficiency_reports.menu.items.email_templates"), icon: "mail", path: adm_deficiency_reports_email_templates_path }
       end),
      (if Adm::DeficiencyReports::DeficiencyReportPolicy.new(current_user, nil).stats?
         { label: t("adm.deficiency_reports.menu.items.stats"), icon: "bar_chart", path: adm_deficiency_reports_stats_path }
       end),
      (if Adm::DeficiencyReports::SettingPolicy.new(current_user, nil).show?
         { label: t("adm.deficiency_reports.menu.items.ai_settings"), icon: "smart_toy", path: adm_deficiency_reports_ai_settings_path }
       end)
    ].compact
  end

  private

    def sample_email_template
      ::SiteCustomization::EmailTemplate.new(
        mailer_class: "DeficiencyReportMailer",
        mailer_action: "notify_officer"
      )
    end
end
