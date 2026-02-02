class Adm::MenuComponent < Adm::BaseMenuComponent
  # rubocop:disable Layout/LineLength
  def menu_items
    [
      { label: t("adm.menu.items.home"),          icon: "home",             path: adm_root_path },
      { label: t("adm.menu.items.projekts"),      icon: "folder_open",      path: adm_projekts_path },
      { label: t("adm.menu.items.application"),   icon: "desktop_windows",  path: "#", subitems: application_subitems },
      { label: t("adm.menu.items.profiles"),      icon: "3p",               path: "#", subitems: profiles_subitems },
      { label: t("adm.menu.items.notifications"), icon: "send",             path: "#" },
      { label: t("adm.menu.items.stats"),         icon: "bar_chart_4_bars", path: "#" },
      { label: t("adm.menu.items.apps"),          icon: "dashboard",        path: "#" }
    ]
  end

  private

    def application_subitems
      [
        { label: t("adm.menu.items.application_subitems.homepage"),              path: adm_homepage_path },
        { label: t("adm.menu.items.application_subitems.landing_pages"),         path: adm_landing_pages_path },
        { label: t("adm.menu.items.application_subitems.documents"),             path: adm_documents_path },
        { label: t("adm.menu.items.application_subitems.navbar"),                path: adm_navbar_path },
        { label: t("adm.menu.items.application_subitems.metadata_settings"),     path: metadata_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.gdpr_settings"),         path: gdpr_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.registration_settings"), path: registration_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.registered_addresses"),  path: adm_registered_addresses_path },
        { label: t("adm.menu.items.application_subitems.default_map_location"),  path: adm_default_map_location_path },
        { label: t("adm.menu.items.application_subitems.tags"),                  path: adm_tags_path },
        { label: t("adm.menu.items.application_subitems.individual_groups"),     path: adm_individual_groups_path },
        { label: t("adm.menu.items.application_subitems.age_ranges"),            path: adm_age_ranges_path }
      ]
    end

    def profiles_subitems
      [
        { label: t("adm.menu.items.profiles_subitems.administrators"), path: adm_administrators_path },
        { label: t("adm.menu.items.profiles_subitems.projekt_managers"), path: adm_projekt_managers_path },
        { label: t("adm.menu.items.profiles_subitems.deficiency_report_managers"), path: adm_deficiency_report_managers_path },
        # { label: t("adm.menu.items.profiles_subitems.deficiency_report_officers"), path: adm_deficiency_report_officers_path },
        { label: t("adm.menu.items.profiles_subitems.idea_managers"), path: adm_idea_managers_path },

        { label: t("adm.menu.items.profiles_subitems.moderators"), path: adm_moderators_path },

        { label: t("adm.menu.items.profiles_subitems.valuators"), path: adm_valuators_path },
        { label: t("adm.menu.items.profiles_subitems.users"), path: adm_users_path }
      ]
    end
  # rubocop:enable Layout/LineLength
end
