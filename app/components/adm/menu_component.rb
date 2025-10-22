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
      attributes["class"] = ["nav-item-link", ("with-subitems" if item[:subitems])].compact.join(" ")
      attributes["data-adm-menu-target"] = "expandable" if item[:subitems]
      if item[:subitems]
        attributes["aria-expanded"] = item[:subitems].any? { |subitem| current_page?(subitem[:path]) }
      end
      attributes["aria-current"] = "page" if current_page?(item[:path])
      attributes["role"] = "button" if item[:subitems]

      attributes
    end

    # rubocop:disable Layout/LineLength
    def menu_items
      [
        { label: t("adm.menu.items.home"),          icon: "home",             path: adm_root_path },
        { label: t("adm.menu.items.projekts"),      icon: "folder_open",      path: adm_projekts_path },
        { label: t("adm.menu.items.application"),   icon: "desktop_windows",  path: "#", subitems: application_subitems },
        { label: t("adm.menu.items.profiles"),      icon: "3p",               path: "#" },
        { label: t("adm.menu.items.notifications"), icon: "send",             path: "#" },
        { label: t("adm.menu.items.stats"),         icon: "bar_chart_4_bars", path: "#" },
        { label: t("adm.menu.items.apps"),          icon: "dashboard",        path: "#" }
      ]
    end

    def application_subitems
      [
        { label: t("adm.menu.items.application_subitems.homepage"),      path: "#" },
        { label: t("adm.menu.items.application_subitems.landing_pages"), path: "#" },
        { label: t("adm.menu.items.application_subitems.documents"),     path: "#" },
        { label: t("adm.menu.items.application_subitems.navbar"),        path: "#" }
      ]
    end
    # rubocop:enable Layout/LineLength
end
