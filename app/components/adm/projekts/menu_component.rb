class Adm::Projekts::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.projekts.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.projekts.menu.items.home"), icon: "home", path: adm_projekts_root_path, active_pattern: %r{/adm/projekts/\d+} },
      (if Adm::Projekts::ProjektManagerPolicy.new(current_user, nil).index?
         { label: t("adm.projekts.menu.items.managers"), icon: "badge", path: adm_projekts_managers_path }
       end),
      (if Adm::Projekts::InspirationPolicy.new(current_user, nil).show?
         { label: t("adm.projekts.menu.items.inspiration"), icon: "travel_explore", path: adm_projekts_inspiration_path, active_prefix: "/adm/projekts/inspiration" }
       end),
      (if Adm::Projekts::ProjektPolicy.new(current_user, nil).create?
         { label: t("adm.projekts.menu.items.instance_import"), icon: "move_down", path: new_adm_projekts_instance_import_path, active_prefix: "/adm/projekts/instance_import" }
       end),
      (if Adm::Projekts::SettingPolicy.new(current_user, nil).show?
         { label: t("adm.projekts.menu.items.settings"), icon: "settings", path: adm_projekts_settings_path }
       end)
    ].compact
  end
end
