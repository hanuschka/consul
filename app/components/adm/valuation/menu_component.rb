class Adm::Valuation::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.valuation.menu.aria_label")
  end

  def menu_items
    [
      (if current_user&.administrator?
         { label: t("adm.valuation.menu.items.valuators"), icon: "badge", path: adm_valuators_path, active_prefix: "/adm/valuators" }
       end),
      { label: t("adm.valuation.menu.items.investments"), icon: "account_balance_wallet", path: adm_valuation_root_path }
    ].compact
  end
end
