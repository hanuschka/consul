class Adm::HeaderComponent < ApplicationComponent
  renders_one :hint, Adm::HintComponent

  def initialize(title:, breadcrumbs: [], back_button_url: nil, narrow: false, frontend_url: nil)
    @title = title
    @breadcrumbs = breadcrumbs
    @back_button_url = back_button_url
    @narrow = narrow
    @frontend_url = frontend_url
  end

  def breadcrumb_item(breadcrumb, is_last)
    li_options = {
      class: ["breadcrumb-item", ("active" if is_last)].compact.join(" "),
      aria: (is_last ? { current: "page" } : {})
    }
    li_options[:id] = breadcrumb[:id] if breadcrumb[:id].present?

    item = content_tag(:li, **li_options) do
      breadcrumb_item_content(breadcrumb, is_last)
    end

    if is_last
      item
    else
      item + content_tag(:span, "arrow_forward_ios", class: "material-symbols-outlined breadcrumb-divider")
    end
  end

  def breadcrumb_item_content(breadcrumb, is_last)
    icon_html = breadcrumb[:icon].present? ? icon_tag(breadcrumb[:icon]) : "".html_safe
    label = breadcrumb[:name]

    if is_last
      tag.span { icon_html + label }
    elsif breadcrumb[:url].blank?
      tag.span { icon_html + label }
    else
      link_to breadcrumb[:url] do
        icon_html + label
      end
    end
  end

  private

    def icon_tag(icon_name)
      content_tag(:span, icon_name, class: "material-symbols-outlined breadcrumb-icon", aria: { hidden: true })
    end
end
