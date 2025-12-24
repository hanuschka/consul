class KernFormBuilder < ActionView::Helpers::FormBuilder
  INPUT_METHODS = %i[
    text_field
    text_area
    date_field
    number_field
    password_field
    email_field
  ].freeze

  INPUT_METHODS.each do |method|
    define_method(method) do |field, options = {}|
      field_errors = field_errors(field)
      hint_text = options.delete(:hint)

      options[:class] = input_classes(options[:class], field_errors)
      options[:aria]  = input_aria(field, field_errors, hint_text)

      form_group(field, field_errors, options, hint_text) do
        super(field, options)
      end
    end
  end

  def select(field, choices = nil, options = {}, html_options = {})
    field_errors = field_errors(field)
    hint_text = options.delete(:hint)

    html_options[:class] = input_classes(html_options[:class], field_errors)
    html_options[:aria]  = input_aria(field, field_errors, hint_text)

    form_group(field, field_errors, html_options, hint_text) do
      super(field, choices, options, html_options)
    end
  end

  private

    ## Structure

    def form_group(field, field_errors, options, hint_text)
      wrapper_class = merge_css_classes(
        "kern-form-input",
        ("kern-form-input--error" if field_errors.any?)
      )

      @template.content_tag(:div, class: wrapper_class) do
        @template.safe_join(
          [
            build_label(field, options),
            hint_html(field, hint_text),
            yield,
            error_html(field, field_errors)
          ].compact
        )
      end
    end

    ## Label

    def build_label(field, options)
      label_option = options.delete(:label)
      return if label_option == false

      text = label_option.is_a?(String) ? label_option : nil
      label(field, text, class: "kern-label")
    end

    ## Hint

    def hint_html(field, hint_text)
      return if hint_text.blank?

      @template.content_tag(:div, hint_text, class: "kern-hint", id: hint_id(field))
    end

    ## Errors

    def field_errors(field)
      object.errors[field] || []
    end

    def error_html(field, field_errors)
      return if field_errors.empty?

      @template.content_tag(:p, class: "kern-error", id: error_id(field), role: "alert") do
        @template.safe_join(
          [
            @template.content_tag(
              :span, "", class: "kern-icon kern-icon--danger kern-icon--md", aria: { hidden: "true" }
            ),
            @template.content_tag(:span, field_errors.join(", "), class: "kern-body")
          ]
        )
      end
    end

    ## ARIA

    def input_aria(field, field_errors, hint_text)
      described_by = []
      described_by << error_id(field) if field_errors.any?
      described_by << hint_id(field) if hint_text.present?

      return {} if described_by.empty?

      { describedby: described_by.join(" ") }
    end

    ## Classes

    def input_classes(existing, field_errors)
      merge_css_classes(
        "kern-form-input__input",
        existing,
        ("kern-form-input__input--error" if field_errors.any?)
      )
    end

    ##  IDs

    def hint_id(field)
      "#{sanitized_object_name}_#{field}_hint"
    end

    def error_id(field)
      "#{sanitized_object_name}_#{field}_error"
    end

    def sanitized_object_name
      object_name.to_s.gsub(/[\[\]]+/, "_").chomp("_")
    end

    ## Utils

    def merge_css_classes(*classes)
      classes.compact.flatten.join(" ")
    end
end
