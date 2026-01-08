class Adm::MenuComponent < ApplicationComponent
  delegate :material_icon, to: :helpers

  def render_list(list)
    content_tag :ul, class: "nav-item-list" do
      safe_join(list.map { |item| menu_item(item) })
    end
  end

  def menu_item(item)
    class_list = ["nav-item", ("active" if current_page?(item[:path]))].compact.join(" ")

    content_tag :li, class: class_list do
      concat(link_to(item[:path] || "#", link_attributes(item)) do
        if item[:icon]
          concat tag.span(class: "material-symbols-outlined", aria: { hidden: "true" }) { item[:icon] }
        end
        concat item[:label]
      end)

      concat(render_list(item[:subitems])) if item[:subitems]
    end
  end

  private

    def link_attributes(item)
      attributes = {}
      attributes["class"] = ["nav-item-link"]
      attributes["data-adm-menu-target"] = "expandable" if item[:subitems]
      if item[:subitems]
        attributes["class"] << "with-subitems"
        attributes["class"] << "expanded" if item[:subitems].any? { |subitem| current_page?(subitem[:path]) }
        attributes["aria-expanded"] = item[:subitems].any? { |subitem| current_page?(subitem[:path]) }
      end
      attributes["aria-current"] = "page" if current_page?(item[:path])
      attributes["role"] = "button" if item[:subitems]

      attributes["class"] = attributes["class"].compact.join(" ")

      attributes
    end

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

    def application_subitems
      [
        { label: t("adm.menu.items.application_subitems.homepage"),          path: adm_homepage_path },
        { label: t("adm.menu.items.application_subitems.landing_pages"),     path: adm_landing_pages_path },
        { label: t("adm.menu.items.application_subitems.documents"),         path: adm_documents_path },
        { label: t("adm.menu.items.application_subitems.navbar"),            path: adm_navbar_path },
        { label: t("adm.menu.items.application_subitems.metadata_settings"), path: metadata_adm_settings_path },
        { label: t("adm.menu.items.application_subitems.gdpr_settings"),     path: gdpr_adm_settings_path }
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
