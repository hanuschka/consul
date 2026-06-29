class Adm::Valuation::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.valuation.menu.aria_label")
  end

  def menu_items
    [
      { label: t("adm.valuation.menu.items.home"), icon: "home", path: adm_valuation_root_path },
      (if Adm::ValuatorPolicy.new(current_user, Valuator).index?
         { label: t("adm.valuation.menu.items.valuators"), icon: "badge", path: adm_valuators_path, active_prefix: "/adm/valuators" }
       end),
      (if Adm::Valuation::SettingPolicy.new(current_user, nil).show?
         { label: t("adm.valuation.menu.items.settings"), icon: "settings", path: adm_valuation_settings_path }
       end)
    ].compact
  end
end
