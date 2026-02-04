class Adm::Projekts::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.projekts.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.projekts.menu.items.projekts"), icon: "folder", path: adm_projekts_root_path },
      { label: t("adm.projekts.menu.items.managers"), icon: "badge", path: adm_projekts_managers_path }
    ]
  end
end
