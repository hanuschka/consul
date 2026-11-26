class Adm::Offers::MenuComponent < Adm::BaseMenuComponent
  def aria_label
    t("adm.offers.menu.aria_label")
  end

  def menu_items
    [offers_item, imports_item, categories_item, providers_item, managers_item, settings_item].compact
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

    def imports_item
      return unless Adm::Offers::OfferPolicy.new(current_user, nil).import?

      {
        label: t("adm.offers.menu.items.imports"),
        icon: "upload_file",
        path: new_adm_offers_import_path,
        active_prefix: "/adm/offers/import"
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

    def providers_item
      return unless Adm::Offers::ProviderPolicy.new(current_user, nil).index?

      {
        label: t("adm.offers.menu.items.providers"),
        icon: "badge",
        path: adm_offers_providers_path,
        active_prefix: "/adm/offers/providers"
      }
    end

    def managers_item
      return unless Adm::OfferManagerPolicy.new(current_user, nil).index?

      {
        label: t("adm.offers.menu.items.managers"),
        icon: "admin_panel_settings",
        path: adm_offers_managers_path,
        active_prefix: "/adm/offers/managers"
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
