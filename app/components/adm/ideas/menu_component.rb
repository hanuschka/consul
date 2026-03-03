class Adm::Ideas::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.ideas.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.ideas.menu.items.ideas"), icon: "lightbulb", path: adm_ideas_root_path },
      { label: t("adm.ideas.menu.items.officers"), icon: "badge", path: adm_ideas_officers_path },
      { label: t("adm.ideas.menu.items.categories"), icon: "category", path: adm_ideas_categories_path },
      { label: t("adm.ideas.menu.items.settings"), icon: "settings", path: adm_ideas_settings_path },
      { label: t("adm.ideas.menu.items.districts"), icon: "location_city", path: adm_ideas_districts_path }
    ]
  end
end
