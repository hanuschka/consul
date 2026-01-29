class Adm::HeaderComponent < ApplicationComponent
  def initialize(title:, breadcrumbs: [])
    @title = title
    @breadcrumbs = breadcrumbs
  end

  def breadcrumb_item(breadcrumb, is_last)
    item = content_tag(:li,
                class: ["breadcrumb-item", ("active" if is_last)].compact.join(" "),
                aria: (is_last ? { current: "page" } : {})
    ) do
      breadcrumb_item_content(breadcrumb, is_last)
    end

    if is_last
      item
    else
      item + content_tag(:span, "arrow_forward_ios", class: "material-symbols-outlined breadcrumb-divider")
    end
  end

  def breadcrumb_item_content(breadcrumb, is_last)
    if is_last || breadcrumb[:url].blank?
      tag.span(breadcrumb[:name])
    else
      link_to breadcrumb[:name], breadcrumb[:url]
    end
  end
end
