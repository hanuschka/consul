class Adm::Moderation::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.moderation.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.moderation.menu.users"), icon: "block", path: adm_moderation_users_path }
    ]
  end
end
