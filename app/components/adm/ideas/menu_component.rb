class Adm::Ideas::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    feature = Setting["ideas.feature_name"].presence
    feature ? t("adm.ideas.menu.aria_label_feature", feature: feature) : t("adm.ideas.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.ideas.menu.items.home"), icon: "home", path: adm_ideas_root_path },
      (if Adm::Ideas::OfficerPolicy.new(current_user, nil).index?
         { label: t("adm.ideas.menu.items.officers"), icon: "badge", path: adm_ideas_officers_path }
       end),
      (if Adm::Ideas::SettingPolicy.new(current_user, nil).show?
         { label: t("adm.ideas.menu.items.settings"), icon: "settings", path: adm_ideas_settings_path, active_pattern: %r{/adm/ideas/settings(/dashboard)?\z} }
       end),
      (if Adm::Ideas::CategoryPolicy.new(current_user, nil).index?
         { label: t("adm.ideas.menu.items.categories"), icon: "category", path: adm_ideas_categories_path }
       end),
      (if Adm::Ideas::DistrictPolicy.new(current_user, nil).index?
         { label: t("adm.ideas.menu.items.districts"), icon: "location_city", path: adm_ideas_districts_path }
       end)
    ].compact
  end
end
