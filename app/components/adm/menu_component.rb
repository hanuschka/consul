class Adm::MenuComponent < ApplicationComponent
  delegate :material_icon, to: :helpers

  def render_list(list)
    content_tag :ul do
      safe_join( list.map { |item| menu_item(item) } )
    end
  end

  def menu_item(item)
    class_list = ["nav-item", ("active" if current_page?(item[:path] || "#"))].compact.join(" ")

    content_tag :li, class: class_list do
      concat(link_to(item[:path] || "#") do
        concat tag.span(class: "material-symbols-outlined") { item[:icon] } if item[:icon]
        concat item[:label]
        concat tag.span(class: "material-symbols-outlined") { "chevron_forward" } if item[:subitems]
      end)

      concat(render_list(item[:subitems])) if item[:subitems]
    end
  end

  private

    def menu_items
      [
        { label: "Home",          icon: "home",             path: adm_root_path },
        { label: "Projekts",      icon: "folder_open",      path: adm_projekts_path },
        { label: "Application",   icon: "desktop_windows",  subitems: application_subitems },
        { label: "Profile",       icon: "3p",               path: "#" },
        { label: "Notification",  icon: "send",             path: "#" },
        { label: "Statistics",    icon: "bar_chart_4_bars", path: "#" },
        { label: "Apps",          icon: "dashboard",        path: "#" }
      ]
    end

    def application_subitems
      [
        { label: "Homepage",          path: "#" },
        { label: "Landingpages",      path: "#" },
        { label: "Eigene Dokumente",  path: "#" },
        { label: "Navigationsleiste", path: "#" }
      ]
    end
end
