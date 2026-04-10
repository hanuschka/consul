class Adm::HeaderComponent < ApplicationComponent
  renders_one :hint, Adm::HintComponent
  renders_one :actions

  def initialize(title:, breadcrumbs: [], back_button_url: nil, narrow: false, compact: false, frontend_url: nil)
    @title = title
    @breadcrumbs = breadcrumbs
    @back_button_url = back_button_url
    @narrow = narrow
    @compact = compact
    @frontend_url = frontend_url
  end

  def before_render
    @frontend_url, @frontend_label = resolve_frontend_url_and_label
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

    label_html = tag.span(label, class: "breadcrumb-label")

    if is_last
      tag.span { icon_html + label_html }
    elsif breadcrumb[:url].blank?
      tag.span { icon_html + label_html }
    else
      link_to breadcrumb[:url] do
        icon_html + label_html
      end
    end
  end

  private

    def resolve_frontend_url_and_label
      t = ->(key) { I18n.t("components.adm.header_component.frontend_labels.#{key}") }

      projekt_phase = controller.instance_variable_get(:@projekt_phase)
      projekt = controller.instance_variable_get(:@projekt) || projekt_phase&.projekt

      if projekt
        base = "/#{projekt.page.slug}"
        url = projekt_phase ? "#{base}?projekt_phase_id=#{projekt_phase.id}#projekt-footer" : base
        return [url, t.call(:projekt)]
      end

      landing_page = controller.instance_variable_get(:@landing_page)
      return ["/#{landing_page.slug}", t.call(:landing_page)] if landing_page&.slug.present?

      if controller.class.module_parent_name == "Adm::DeficiencyReports"
        return [helpers.deficiency_reports_path, t.call(:deficiency_reports)]
      end

      if controller.class.module_parent_name == "Adm::Ideas"
        return [helpers.ideas_path, t.call(:ideas)]
      end

      [helpers.root_path, t.call(:default)]
    end

    def icon_tag(icon_name)
      content_tag(:span, icon_name, class: "material-symbols-outlined breadcrumb-icon", aria: { hidden: true })
    end
end
