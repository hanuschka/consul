require_dependency Rails.root.join("app", "components", "admin", "menu_component").to_s

class Admin::MenuComponent < ApplicationComponent

  private

    def deficiency_reports?
      return true if controller_name == "deficiency_reports"

      %w[officers categories statuses settings areas].include?(controller_name) &&
        controller.class.module_parent == Admin::DeficiencyReports
    end

    def profiles?
      %w[administrators projekt_managers organizations officials moderators valuators managers
         users unregistered_newsletter_subscribers].include?(controller_name)
    end

    def settings?
      controllers_names = ["settings", "tags", "geozones", "images", "content_blocks",
                           "local_census_records", "imports", "age_restrictions", "individual_groups", "individual_group_values"]
      controllers_names.include?(controller_name) &&
        controller.class.module_parent != Admin::Poll::Questions::Answers &&
        controller.class != Admin::DeficiencyReports::SettingsController
    end

    def customization?
      ["pages", "banners", "modal_notifications", "information_texts", "documents"].include?(controller_name) ||
        homepage? || pages?
    end

    def registered_addresses?
      %w[registered_addresses registered_address_groupings registered_address_streets].include?(controller_name)
    end

    def projekts_link
      [
        t("custom.admin.menu.projekts"),
        admin_projekts_path,
        controller_name == "projekts",
        class: "projekts-link"
      ]
    end

    def deficiency_reports_links
      link_to(t("custom.admin.menu.deficiency_reports_title"), "#", class: "deficiency-reports-link") +
        link_list(
          deficiency_reports_list,
          deficiency_report_officers,
          deficiency_report_categories,
          deficiency_report_statuses,
          deficiency_report_settings,
          deficiency_report_areas,
          id: "deficiency_reports_menu", class: ("is-active" if deficiency_reports?)
        )
    end

    def deficiency_reports_list
      [
        t("custom.admin.menu.deficiency_reports.list"),
        admin_deficiency_reports_path,
        controller_name == "deficiency_reports"
      ]
    end

    def deficiency_report_officers
      [
        t("custom.admin.menu.deficiency_reports.officers"),
        admin_deficiency_report_officers_path,
        controller_name == "officers" && controller.class.module_parent == Admin::DeficiencyReports
      ]
    end

    def deficiency_report_categories
      [
        t("custom.admin.menu.deficiency_reports.categories"),
        admin_deficiency_report_categories_path,
        controller_name == "categories" && controller.class.module_parent == Admin::DeficiencyReports
      ]
    end

    def deficiency_report_statuses
      [
        t("custom.admin.menu.deficiency_reports.statuses"),
        admin_deficiency_report_statuses_path,
        controller_name == "statuses" && controller.class.module_parent == Admin::DeficiencyReports
      ]
    end

    def deficiency_report_settings
      [
        t("custom.admin.menu.deficiency_reports.settings"),
        admin_deficiency_report_settings_path,
        controller_name == "settings" && controller.class.module_parent == Admin::DeficiencyReports
      ]
    end

    def deficiency_report_areas
      [
        t("custom.admin.menu.deficiency_reports.areas"),
        admin_deficiency_report_areas_path,
        controller_name == "areas" && controller.class.module_parent == Admin::DeficiencyReports
      ]
    end

    def registered_addresses_links
      link_to(t("custom.admin.menu.title_registered_addresses"), "#", class: "registered-addresses-link") +
        link_list(
          registered_addresses_list,
          registered_address_groupings_list,
          registered_address_streets_list, 
          id: "registered-addresses-link", class: ("is-active" if registered_addresses?)
        )
    end

    def registered_addresses_list
      [
        t("custom.admin.menu.registered_addresses.list"),
        admin_registered_addresses_path,
        controller_name == "registered_addresses"
      ]
    end

    def registered_address_groupings_list
      [
        t("custom.admin.menu.registered_address_groupings.list"),
        admin_registered_address_groupings_path,
        controller_name == "registered_address_groupings"
      ]
    end

    def registered_address_streets_list
      [
        t("custom.admin.menu.registered_address_streets.list"),
        admin_registered_address_streets_path,
        controller_name == "registered_address_streets"
      ]
    end

    def projekt_managers_link
      [
        t("custom.admin.menu.projekt_managers"),
        admin_projekt_managers_path,
        controller_name == "projekt_managers"
      ]
    end

    def modal_notifications_link
      [
        t("custom.admin.menu.modal_notification"),
        admin_modal_notifications_path,
        controller_name == "modal_notifications"
      ]
    end

    def age_restrictions_link
      [
        t("custom.admin.menu.age_restrictions"),
        admin_age_restrictions_path,
        controller_name == "age_restrictions"
      ]
    end

    def settings_link
      [
        t("admin.menu.settings"),
        admin_settings_path,
        controller_name == "settings" &&
          controller.class != Admin::DeficiencyReports::SettingsController
      ]
    end

    def individual_groups_link
      [
        t("custom.admin.menu.individual_groups"),
        admin_individual_groups_path,
        ["individual_groups", "individual_group_values"].include?(controller_name)
      ]
    end

    def unregistered_newsletter_subscribers_link
      [
        t("custom.admin.menu.unregistered_newsletter_subscribers.list"),
        admin_unregistered_newsletter_subscribers_path,
        ["unregistered_newsletter_subscribers"].include?(controller_name)
      ]
    end

    def booths?
      %w[officers booths shifts booth_assignments officer_assignments].include?(controller_name) && controller.class.module_parent == Admin::Poll ||
        controller_name == "polls" && action_name == "booth_assignments"
    end

    def matomo_link
      [
        t("custom.admin.menu.matomo"),
        admin_matomo_path,
        controller_name == "matomo",
        class: "matomo-link"
      ]
    end
end
