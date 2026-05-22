module KernHelper
  def kern_button(icon: nil, text: nil, autofocus: false, type: :button, style: :primary, disabled: false, **options)
    classes = ["kern-btn", "kern-btn--#{style}", options.delete(:class)].compact.join(" ")

    button_tag(type: type, class: classes, autofocus: autofocus, disabled: disabled, **options) do
      if icon.present?
        concat(content_tag(:span, icon, class: "kern-label material-symbols-outlined", "aria-hidden": "true"))
      end
      concat(content_tag(:span, text, class: "kern-label")) if text.present?
    end
  end

  def kern_link_button(url, icon: nil, text: nil, autofocus: false, style: :secondary, **options)
    classes = ["kern-btn", "kern-btn--#{style}", options.delete(:class)].compact.join(" ")

    link_to url, class: classes, autofocus: autofocus, **options do
      if icon.present?
        concat(content_tag(:span, icon, class: "kern-label material-symbols-outlined", "aria-hidden": "true"))
      end

      concat(content_tag(:span, text, class: "kern-label")) if text.present?
    end
  end

  def new_resource_link(url, link_name, **options)
    content_tag(:div, class: "d-flex justify-content-start mb-4") do
      kern_link_button(url, text: link_name)
    end
  end

  # POST-variant of new_resource_link. Renders a button_to (form-wrapped button)
  # styled identically to kern_link_button(style: :secondary) so it visually
  # matches the legacy "new resource" link button.
  def new_resource_button(url, link_name, method: :post, style: :secondary, form_data: {}, **options)
    classes = ["kern-btn", "kern-btn--#{style}", options.delete(:class)].compact.join(" ")
    content_tag(:div, class: "d-flex justify-content-start mb-4") do
      button_to(url, method: method, class: classes, form: { data: form_data }, **options) do
        content_tag(:span, link_name, class: "kern-label")
      end
    end
  end

  def form_submit_button(text: I18n.t("shared.submit"), icon: "save", disabled: false, **options)
    content_tag(:div, class: "d-flex justify-content-start mb-4") do
      kern_button(text: text, icon: icon, type: "submit", disabled: disabled, **options)
    end
  end

  def empty_state(title:, description: nil, icon: "folder_open", link_url: nil, link_text: nil, link_class: "adm-empty-state__link kern-button kern-button--outline mt-3", link_target: nil, link_rel: nil)
    content_tag(:div, class: "adm-empty-state") do
      concat(content_tag(:div, content_tag(:span, icon, class: "adm-empty-state__icon material-symbols-outlined", "aria-hidden": "true"), class: "adm-empty-state__icon-wrap"))
      concat(content_tag(:p, title, class: "adm-empty-state__title"))
      concat(content_tag(:p, description, class: "adm-empty-state__description")) if description.present?
      if link_url.present? && link_text.present?
        link_opts = { class: link_class }
        link_opts[:target] = link_target if link_target.present?
        link_opts[:rel] = link_rel if link_rel.present?
        concat(link_to(link_text, link_url, **link_opts))
      end
    end
  end

  def kern_alert(title:, style: :info, &block)
    content_tag(:div, class: "kern-alert kern-alert--#{style}", role: "alert") do
      header = content_tag(:div, class: "kern-alert__header") do
        concat(content_tag(:span, nil, class: "kern-icon kern-icon--#{style}", "aria-hidden": "true"))
        concat(content_tag(:span, title, class: "kern-title"))
      end
      if block
        body = content_tag(:div, class: "kern-alert__body") { capture(&block) }
        safe_join([header, body])
      else
        header
      end
    end
  end
end
