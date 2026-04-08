class Adm::Valuation::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.valuation.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.valuation.menu.items.investments"), icon: "account_balance_wallet", path: adm_valuation_root_path }
    ]
  end
end
