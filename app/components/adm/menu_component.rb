class Adm::MenuComponent < Adm::BaseMenuComponent
  # rubocop:disable Layout/LineLength
  def menu_items
    [
      { label: t("adm.menu.items.home"),          icon: "home",             path: adm_root_path },
      { label: t("adm.menu.items.team"),          icon: "badge",            path: adm_administrators_path, active_prefix: "/adm/administrators" },
      { label: t("adm.menu.items.application"),   icon: "desktop_windows",  path: "#", subitems: application_subitems },
      { label: t("adm.menu.items.users"),         icon: "3p",               path: adm_users_path, active_prefix: "/adm/users" },
      { label: t("adm.menu.items.notifications"), icon: "send",             path: "#", subitems: notifications_subitems },
      { label: t("adm.menu.items.stats"),             icon: "bar_chart_4_bars", path: "#", subitems: stats_subitems },
      { label: t("adm.menu.items.files"),         icon: "folder",           path: "#", subitems: files_subitems },
      { label: t("adm.menu.items.apps"),              icon: "dashboard",        path: adm_apps_path },
      { label: t("adm.menu.items.api"),               icon: "integration_instructions", path: "#", subitems: api_subitems },
      { label: t("adm.menu.items.developer"),         icon: "logo_dev",         path: "#", subitems: developer_subitems }
    ]
  end

  private

    def application_subitems
      [
        { label: t("adm.menu.items.application_subitems.homepage"),              path: adm_homepage_path },
        { label: t("adm.menu.items.application_subitems.navbar"),                path: adm_navbar_path },
        { label: t("adm.menu.items.application_subitems.overview_pages"),        path: projekt_adm_overview_pages_path, active_prefix: "/adm/overview_pages" },
        { label: t("adm.menu.items.application_subitems.metadata_settings"),     path: metadata_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.registered_addresses"),  path: adm_registered_addresses_path },
        { label: t("adm.menu.items.application_subitems.registration_settings"), path: registration_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.default_map_location"),  path: adm_default_map_location_path },
        { label: t("adm.menu.items.application_subitems.system_user"),           path: edit_adm_system_user_path, active_prefix: "/adm/system_user" },
        { label: t("adm.menu.items.application_subitems.tags"),                  path: adm_tags_path },
        { label: t("adm.menu.items.application_subitems.age_ranges"),            path: adm_age_ranges_path },
        { label: t("adm.menu.items.application_subitems.individual_groups"),     path: adm_individual_groups_path },
        { label: t("adm.menu.items.application_subitems.gdpr_settings"),         path: gdpr_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.pages"),                 path: adm_site_customization_pages_path, active_prefix: "/adm/site_customization/pages" },
        { label: t("adm.menu.items.application_subitems.features"),              path: adm_features_path,                                              active_prefix: "/adm/features" }
      ]
    end

    def files_subitems
      [
        { label: t("adm.menu.items.files_subitems.images"),             path: adm_files_images_path },
        { label: t("adm.menu.items.files_subitems.documents"),          path: adm_files_documents_path },
        { label: t("adm.menu.items.files_subitems.resource_documents"), path: adm_maintenance_resource_documents_path },
        { label: t("adm.menu.items.files_subitems.file_settings"),      path: file_settings_adm_settings_path }
      ]
    end

    def stats_subitems
      [
        { label: t("adm.menu.items.stats_subitems.overview"), path: adm_statistics_path },
        matomo_subitem
      ].compact
    end

    def api_subitems
      [
        { label: t("adm.menu.items.api_subitems.api_clients"),        path: adm_api_clients_path,        active_prefix: "/adm/api_clients" },
        { label: t("adm.menu.items.api_subitems.api_request_logs"),   path: adm_api_request_logs_path,   active_prefix: "/adm/api_request_logs" },
        { label: t("adm.menu.items.api_subitems.api_changelog"),      path: api_docs_path(anchor: "section/Changelog"), target: "_blank" }
      ]
    end

    def developer_subitems
      [
        { label: t("adm.menu.items.developer_subitems.ai_settings"),       path: adm_ai_settings_path,       active_prefix: "/adm/ai_settings" },
        { label: t("adm.menu.items.developer_subitems.external_api_keys"), path: adm_external_api_keys_path, active_prefix: "/adm/external_api_keys" },
        { label: t("adm.menu.items.developer_subitems.machine_translations"), path: adm_machine_translations_path, active_prefix: "/adm/machine_translations" }
      ]
    end

    def matomo_subitem
      return unless feature?("matomo")

      { label: t("adm.menu.items.stats_subitems.matomo"), path: adm_matomo_path }
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
