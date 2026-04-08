class Adm::MenuComponent < Adm::BaseMenuComponent
  # rubocop:disable Layout/LineLength
  def menu_items
    [
      { label: t("adm.menu.items.home"),          icon: "home",             path: adm_root_path },
      { label: t("adm.menu.items.application"),   icon: "desktop_windows",  path: "#", subitems: application_subitems },
      { label: t("adm.menu.items.profiles"),      icon: "3p",               path: "#", subitems: profiles_subitems },
      { label: t("adm.menu.items.notifications"), icon: "send",             path: "#", subitems: notifications_subitems, divider: true },
      { label: t("adm.menu.items.stats"),             icon: "bar_chart_4_bars", path: adm_statistics_path },
      { label: t("adm.menu.items.apps"),              icon: "dashboard",        path: adm_apps_path },
      { label: t("adm.menu.items.developer"),         icon: "logo_dev",         path: "#", subitems: developer_subitems }
    ]
  end

  private

    def application_subitems
      [
        { label: t("adm.menu.items.application_subitems.homepage"),              path: adm_homepage_path },
        { label: t("adm.menu.items.application_subitems.navbar"),                path: adm_navbar_path },
        { label: t("adm.menu.items.application_subitems.metadata_settings"),     path: metadata_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.registered_addresses"),  path: adm_registered_addresses_path },
        { label: t("adm.menu.items.application_subitems.registration_settings"), path: registration_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.default_map_location"),  path: adm_default_map_location_path },
        { label: t("adm.menu.items.application_subitems.tags"),                  path: adm_tags_path },
        { label: t("adm.menu.items.application_subitems.age_ranges"),            path: adm_age_ranges_path },
        { label: t("adm.menu.items.application_subitems.individual_groups"),     path: adm_individual_groups_path },
        { label: t("adm.menu.items.application_subitems.gdpr_settings"),         path: gdpr_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.documents"),             path: adm_documents_path },
        { label: t("adm.menu.items.application_subitems.pages"),                 path: adm_site_customization_edit_page_by_slug_path(slug: "privacy"), active_prefix: "/adm/site_customization/pages" }
      ]
    end

    def profiles_subitems
      [
        # Plattformweit
        { label: t("adm.menu.items.profiles_subitems.administrators"), path: adm_administrators_path },
        { label: t("adm.menu.items.profiles_subitems.moderators"), path: adm_moderators_path },
        { label: t("adm.menu.items.profiles_subitems.officing_managers"), path: adm_officing_managers_path },
        { label: t("adm.menu.items.profiles_subitems.users"), path: adm_users_path },

        # Bereichsspezifisch
        { label: t("adm.menu.items.profiles_subitems.idea_managers"), path: adm_idea_managers_path },
        { label: t("adm.menu.items.profiles_subitems.deficiency_report_managers"), path: adm_deficiency_report_managers_path },
        { label: t("adm.menu.items.profiles_subitems.valuators"), path: adm_valuators_path }
      ]
    end
    def developer_subitems
      [
        { label: t("adm.menu.items.developer_subitems.ai_settings"),        path: adm_ai_settings_path,        active_prefix: "/adm/ai_settings" },
        { label: t("adm.menu.items.developer_subitems.external_api_keys"),  path: adm_external_api_keys_path,  active_prefix: "/adm/external_api_keys" },
        { label: t("adm.menu.items.developer_subitems.api_clients"),        path: adm_api_clients_path,        active_prefix: "/adm/api_clients" },
        { label: t("adm.menu.items.developer_subitems.api_request_logs"),   path: adm_api_request_logs_path,   active_prefix: "/adm/api_request_logs" }
      ]
    end

    def notifications_subitems
      [
        { label: t("adm.menu.items.notifications_subitems.newsletters"), path: adm_newsletters_path, active_prefix: "/adm/newsletters" },
        { label: t("adm.menu.items.notifications_subitems.email_templates"), path: adm_global_email_templates_path },
        { label: t("adm.menu.items.notifications_subitems.modal_notifications"), path: adm_modal_notifications_path }
      ]
    end
  # rubocop:enable Layout/LineLength
end
