class KernFormBuilder < ActionView::Helpers::FormBuilder
  INPUT_METHODS = %i[
    text_field
    text_area
    number_field
    password_field
    email_field
    url_field
    telephone_field
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

  def rich_text_area(field, options = {})
    unless options[:disabled]
      toolbar = options.delete(:toolbar) || @template.ck_editor_class(@template.current_user)
      options[:data] = (options[:data] || {}).merge(controller: "ckeditor", ckeditor_toolbar_value: toolbar)
    end
    text_area(field, options)
  end

  def date_field(field, options = {})
    value = options.fetch(:value) { object&.send(field) }
    options[:value] = value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d") : value.presence

    text_field(field, options.merge(type: "date"))
  end

  def datetime_local_field(field, options = {})
    value = options.fetch(:value) { object&.send(field) }
    options[:value] = value.respond_to?(:strftime) ? value.strftime("%Y-%m-%dT%H:%M") : value.presence

    text_field(field, options.merge(type: "datetime-local"))
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

  def check_box(field, options = {}, checked_value = "1", unchecked_value = "0")
    field_errors = field_errors(field)
    label_text = options.delete(:label)
    hint_text = options.delete(:hint)
    disabled = options[:disabled]

    options[:class] = checkbox_input_classes(options[:class], field_errors)

    checkbox_group(field, field_errors, label_text, hint_text, disabled: disabled) do
      super(field, options, checked_value, unchecked_value)
    end
  end

  def collection_radio_buttons(field, collection, value_method, text_method, options = {}, html_options = {}, &block)
    field_errors = field_errors(field)
    legend_text = options.delete(:legend)
    disabled = options.delete(:disabled)

    if block_given?
      super
    else
      radio_buttons = super(field, collection, value_method, text_method, options, html_options) do |b|
        @template.content_tag(:div, class: "kern-form-check") do
          label_class = disabled ? "kern-label kern-label--disabled" : "kern-label"
          @template.safe_join([
            b.radio_button(class: radio_input_classes(nil, field_errors), disabled: disabled),
            b.label(class: label_class)
          ])
        end
      end

      fieldset_group(field, field_errors, legend_text, radio_buttons)
    end
  end

  def collection_check_boxes(field, collection, value_method, text_method, options = {}, html_options = {}, &block)
    field_errors = field_errors(field)
    legend_text = options.delete(:legend)
    disabled = options.delete(:disabled)

    if block_given?
      super
    else
      check_boxes = super(field, collection, value_method, text_method, options, html_options) do |b|
        @template.content_tag(:div, class: "kern-form-check") do
          label_class = disabled ? "kern-label kern-label--disabled" : "kern-label"
          @template.safe_join([
            b.check_box(class: checkbox_input_classes(nil, field_errors), disabled: disabled),
            b.label(class: label_class)
          ])
        end
      end

      fieldset_group(field, field_errors, legend_text, check_boxes)
    end
  end

  private

    ## Structure

    def fieldset_group(field, field_errors, legend_text, inputs)
      fieldset_class = merge_css_classes(
        "kern-fieldset",
        ("kern-fieldset--error" if field_errors.any?)
      )

      @template.content_tag(:fieldset, class: fieldset_class) do
        @template.safe_join(
          [
            (@template.content_tag(:legend, legend_text, class: "kern-label") if legend_text.present?),
            @template.content_tag(:div, inputs, class: "kern-fieldset__body"),
            error_html(field, field_errors)
          ].compact
        )
      end
    end

    def checkbox_group(field, field_errors, label_text, hint_text, disabled: false)
      wrapper_class = merge_css_classes(
        "kern-form-check mb-3",
        ("kern-form-check--error" if field_errors.any?)
      )

      @template.content_tag(:div, class: wrapper_class) do
        @template.safe_join(
          [
            yield,
            build_checkbox_label(field, label_text, disabled: disabled),
            checkbox_hint_html(hint_text),
            error_html(field, field_errors)
          ].compact
        )
      end
    end

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
      text = append_required_mark(field, text)
      label_class = options[:disabled] ? "kern-label kern-label--disabled" : "kern-label"
      label(field, text, class: label_class)
    end

    def build_checkbox_label(field, label_text, disabled: false)
      return if label_text == false

      text = label_text.is_a?(String) ? label_text : nil
      label_class = disabled ? "kern-label kern-label--disabled" : "kern-label"
      label(field, text, class: label_class)
    end

    ## Hint

    def hint_html(field, hint_text)
      return if hint_text.blank?

      @template.content_tag(:div, hint_text, class: "kern-hint", id: hint_id(field))
    end

    def checkbox_hint_html(hint_text)
      return if hint_text.blank?

      @template.content_tag(:span, hint_text,
                            class: "kern-body kern-body--small",
                            style: "grid-column: 2; padding-left: var(--kern-metric-space-default, 16px);")
    end

    ## Errors

    def field_errors(field)
      object&.errors&.[](field) || []
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

    def checkbox_input_classes(existing, field_errors)
      merge_css_classes(
        "kern-form-check__checkbox",
        existing,
        ("kern-form-check__checkbox--error" if field_errors.any?)
      )
    end

    def radio_input_classes(existing, field_errors)
      merge_css_classes(
        "kern-form-check__radio",
        existing,
        ("kern-form-check__radio--error" if field_errors.any?)
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

    ## Required

    def field_required?(field)
      return false unless object.class.respond_to?(:validators_on)

      object.class.validators_on(field).any? do |v|
        v.is_a?(ActiveModel::Validations::PresenceValidator) &&
          v.options.except(:message).empty?
      end
    end

    def append_required_mark(field, text)
      return text unless field_required?(field)

      base = text || object.class.human_attribute_name(field)
      @template.safe_join([base, " *"])
    end

    ## Utils

    def merge_css_classes(*classes)
      classes.compact.flatten.join(" ")
    end
end
