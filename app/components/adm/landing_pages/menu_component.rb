class Adm::LandingPages::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.landing_pages.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.landing_pages.menu.items.home"), icon: "home", path: adm_landing_pages_root_path },
      (if Adm::LandingPages::LandingPageManagerPolicy.new(current_user, nil).index?
         { label: t("adm.landing_pages.menu.items.managers"), icon: "badge", path: adm_landing_pages_managers_path }
       end),
      (if current_user&.administrator? || current_user&.landing_page_manager?
         { label: t("adm.landing_pages.menu.items.settings"), icon: "settings", path: adm_landing_pages_settings_path }
       end)
    ].compact
  end
end
