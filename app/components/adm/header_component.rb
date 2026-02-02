class Adm::HeaderComponent < ApplicationComponent
  renders_one :hint, Adm::HintComponent

  def initialize(title:, breadcrumbs: [], back_button_url: nil)
    @title = title
    @breadcrumbs = breadcrumbs
    @back_button_url = back_button_url
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
    if is_last
      tag.strong(breadcrumb[:name])
    elsif breadcrumb[:url].blank?
      tag.span(breadcrumb[:name])
    else
      link_to breadcrumb[:name], breadcrumb[:url]
    end
  end
end
