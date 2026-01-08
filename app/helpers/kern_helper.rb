module KernHelper
  def kern_button(icon: nil, text: nil, autofocus: false, type: :button, style: :primary)
    button_tag(type: type, class: "kern-btn kern-btn--#{style}", autofocus: autofocus) do
      if icon.present?
        concat(content_tag(:span, icon, class: "kern-label material-symbols-outlined", "aria-hidden": "true"))
      end
      concat(content_tag(:span, text, class: "kern-label")) if text.present?
    end
  end

  def kern_link_button(url, icon: nil, text: nil, autofocus: false, style: :primary, **options)
    classes = ["kern-btn", "kern-btn--#{style}", options.delete(:class)].compact.join(" ")

    link_to url, class: classes, autofocus: autofocus, **options do
      if icon.present?
        concat(content_tag(:span, icon, class: "kern-label material-symbols-outlined", "aria-hidden": "true"))
      end

      concat(content_tag(:span, text, class: "kern-label")) if text.present?
    end
  end

  def new_resource_link(url, link_name, **options)
    content_tag(:div, class: "d-flex justify-content-end mb-4") do
      kern_link_button(url, text: link_name)
    end
  end

  def localized_fields_for(form, attribute, type, **options)
    fields = I18n.available_locales.map do |locale|
      content_tag(:div, class: "kern-row mb-5") do
        content_tag(:div, class: "kern-col") do
          send("localized_#{type}_input_for", form, attribute, locale, **options)
        end
      end
    end

    safe_join(fields)
  end

  def localized_text_field_input_for(form, attribute, locale, **options)
    form.fields_for :translations, form.object.translation_for(locale) do |tf|
      content_tag(:div, class: "kern-form-input") do
        concat(tf.label(attribute, options.delete(:label) || tf.object.class.human_attribute_name(attribute), class: "kern-label"))
        concat(tf.send(:text_field, attribute, { class: "kern-form-input__input", label: false }.merge(options)))
      end
    end
  end
end
