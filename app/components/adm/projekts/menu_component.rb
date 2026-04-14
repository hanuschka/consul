class Adm::Projekts::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.projekts.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.projekts.menu.items.home"), icon: "home", path: adm_projekts_root_path },
      (if Adm::Projekts::ProjektManagerPolicy.new(current_user, nil).index?
         { label: t("adm.projekts.menu.items.managers"), icon: "badge", path: adm_projekts_managers_path }
       end),
      { label: t("adm.projekts.menu.items.projekts"), icon: "folder", path: adm_projekts_projekts_list_path, active_prefix: "/adm/projekts/list", active_pattern: %r{/adm/projekts/\d+} },
      (if Adm::SettingPolicy.new(current_user, nil).update?
         { label: t("adm.projekts.menu.items.overview_page"), icon: "settings", path: navigation_adm_projekts_overview_page_path, active_prefix: "/adm/projekts/overview_page" }
       end)
    ].compact
  end
end
