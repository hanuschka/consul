class Adm::BaseMenuComponent < ApplicationComponent
  def menu_items
    raise NotImplementedError, "Subclasses must implement #menu_items"
  end

  def aria_label
    t("adm.menu.aria_label")
  end

  def render_list(list)
    content_tag :ul, class: "nav-item-list" do
      safe_join(list.map { |item| menu_item(item) })
    end
  end

  def menu_item(item)
    content_tag :li, class: item_class(item) do
      concat(link_to(item[:path] || "#", link_attributes(item)) do
        concat material_icon(item[:icon]) if item[:icon]
        concat item[:label]
      end)
      concat(render_list(item[:subitems])) if item[:subitems]
    end
  end

  private

    def item_class(item)
      class_names("nav-item", "active": item_active?(item), "divider-before": item[:divider])
    end

    def link_attributes(item)
      has_subitems = item[:subitems].present?
      subitems_expanded = has_subitems && subitem_active?(item[:subitems])

      {
        class: class_names("nav-item-link", "with-subitems": has_subitems, "expanded": subitems_expanded),
        role: ("button" if has_subitems),
        target: item[:target],
        rel: ("noopener" if item[:target]),
        aria: {
          current: ("page" if item_active?(item)),
          expanded: (subitems_expanded if has_subitems)
        },
        data: { adm_menu_target: ("expandable" if has_subitems), adm_menu_id: (item[:icon] if has_subitems) }
      }.compact
    end

    def item_active?(item)
      return true if item[:active_prefix] && request.path.start_with?(item[:active_prefix])
      return true if item[:active_pattern] && request.path.match?(item[:active_pattern])

      current_page?(item[:path])
    end

    def subitem_active?(subitems)
      subitems.any? { |subitem| item_active?(subitem) }
    end

    def material_icon(name)
      tag.span(name, class: "material-symbols-outlined", aria: { hidden: "true" })
    end
end
