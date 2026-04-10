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
      { label: t("adm.landing_pages.menu.items.landing_pages"), icon: "web", path: adm_landing_pages_landing_pages_list_path }
    ].compact
  end
end
