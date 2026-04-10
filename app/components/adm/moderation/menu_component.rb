class Adm::Moderation::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.moderation.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.moderation.menu.items.home"), icon: "home", path: adm_moderation_root_path },
      (if current_user&.administrator?
         { label: t("adm.moderation.menu.items.moderators"), icon: "badge", path: adm_moderators_path, active_prefix: "/adm/moderators" }
       end),
      { label: t("adm.moderation.menu.items.comments"), icon: "comment", path: adm_moderation_comments_path },
      { label: t("adm.moderation.menu.items.proposals"), icon: "article", path: adm_moderation_proposals_path },
      { label: t("adm.moderation.menu.items.budget_investments"), icon: "payments", path: adm_moderation_budget_investments_path },
      { label: t("adm.moderation.menu.items.users"), icon: "block", path: adm_moderation_users_path }
    ].compact
  end
end
