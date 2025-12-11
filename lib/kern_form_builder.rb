class KernFormBuilder < ActionView::Helpers::FormBuilder
  %i[text_field text_area date_field number_field password_field email_field].each do |method|
    define_method(method) do |field, options = {}|
      if errors(field).any?
        options[:class] = [options[:class], "kern-form-input__input--error"].compact.join(" ")
      end

      form_group(field, options) do
        super(field, options)
      end
    end
  end

  def select(field, choices = nil, options = {}, html_options = {})
    form_group(field, html_options) do
      super(field, choices, options, html_options)
    end
  end

  private

    def form_group(field, options)
      wrapper_class = ["kern-form-input", ("kern-form-input--error" if errors(field).any?)].compact.join(" ")

      @template.content_tag(:div, class: wrapper_class) do
        [
          yield,
          success_html(field),
          error_html(field)
        ].join.html_safe
      end
    end

    def success_html(field)
      return "" unless @template.flash["success"].present? && errors(field).blank?

      @template.content_tag(:div, I18n.t("adm.components.attribute_editor.saved"), class: "success-message", data: { "components-adm-attribute-editor-target": "successMessage" })
    end

    def errors(field)
      object&.errors[field] || []
    end

    def error_html(field)
      return "" if errors(field).blank?

      @template.content_tag(:p, class: "kern-error", role: "alert", data: { "components-adm-attribute-editor-target": "errorMessage" }) do
        @template.concat @template.content_tag(:span, "", class: "kern-icon kern-icon--danger kern-icon--md", aria: { hidden: "true" })
        @template.concat @template.content_tag(:span, errors(field).join(", "), class: "kern-body")
      end
    end
end
