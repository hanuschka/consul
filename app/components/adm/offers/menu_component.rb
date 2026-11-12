class Adm::Offers::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.offers.menu.aria_label")
  end

  def menu_items
    [offers_item, categories_item, settings_item].compact
  end

  private

    def offers_item
      return unless Adm::Offers::OfferPolicy.new(current_user, nil).index?

      {
        label: t("adm.offers.menu.items.offers"),
        icon: Adm::Section::ICONS["offers"][:material],
        path: adm_offers_root_path,
        active_pattern: %r{\A/adm/offers(/\d+(/.*)?)?\z}
      }
    end

    def categories_item
      return unless Adm::Offers::CategoryPolicy.new(current_user, nil).index?

      {
        label: t("adm.offers.menu.items.categories"),
        icon: "category",
        path: adm_offers_categories_path,
        active_prefix: "/adm/offers/categories"
      }
    end

    def settings_item
      return unless Adm::Offers::SettingPolicy.new(current_user, nil).show?

      {
        label: t("adm.offers.menu.items.settings"),
        icon: "settings",
        path: adm_offers_settings_path
      }
    end
end
