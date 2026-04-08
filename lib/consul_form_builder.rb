class ConsulFormBuilder < FoundationRailsHelper::FormBuilder
  include ActionView::Helpers::SanitizeHelper

  def enum_select(attribute, options = {}, html_options = {})
    choices = object.class.send(attribute.to_s.pluralize).keys.map do |name|
      [object.class.human_attribute_name("#{attribute}.#{name}"), name]
    end

    select attribute, choices, options, html_options
  end

  %i[text_field text_area date_field number_field password_field email_field].each do |field|
    define_method field do |attribute, options = {}|
      label_with_hint(attribute, options.merge(label_options: label_options_for(options))) +
        super(attribute, options.merge(
          label: false, hint: nil,
          aria: field_aria(attribute, options)
        ))
    end
  end

  def check_box(attribute, options = {})
    if options[:label] == false
      super(attribute, options.merge(aria: field_aria(attribute, options)))
    else
      label = tag.span AdminWYSIWYGSanitizer.new.sanitize(label_text(attribute, options[:label])), class: "checkbox" #customized

      super(attribute, options.merge(
        label: label,
        label_options: { class: ["checkbox-label", options[:class]].compact.join(" ") }.merge(label_options_for(options)), #customized
        aria: field_aria(attribute, options)
      ))
    end
  end

  def radio_button(attribute, tag_value, options = {})
    if options[:label] == false
      super
    else
      default_label = object.class.human_attribute_name("#{attribute}_#{tag_value}")

      super(attribute, tag_value, { label: default_label }.merge(options))
    end
  end

  def select(attribute, choices, options = {}, html_options = {})
    label_with_hint(attribute, options.merge(label_options: label_options_for(options))) +
      super(attribute, choices, options.merge(label: false, hint: nil), html_options.merge({
        aria: field_aria(attribute, options)
      }))
  end

  def error_for(attribute, options = {})
    return if !error?(attribute)

    class_name = "form-error is-visible"
    class_name += " #{options[:class]}" if options[:class]

    error_messages = object.errors[attribute].join(", ")
    error_messages = error_messages.html_safe if options[:html_safe_errors]

    content_tag(
      :small, error_messages,
      class: class_name.sub("is-invalid-input", ""),
      id: error_id(attribute),
      role: "alert"
    )
  end

  private

    def custom_label(attribute, text, options)
      if text == false
        super
      else
        super(attribute, AdminWYSIWYGSanitizer.new.sanitize(label_text(attribute, text)), options) #customized
      end
    end

    def label_with_hint(attribute, options)
      custom_label(attribute, options[:label], options[:label_options]) +
        help_text(attribute, options)
    end

    def label_text(attribute, text)
      if text.nil? || text == true
        default_label_text(object, attribute)
      else
        text
      end
    end

    def label_options_for(options)
      label_options = options[:label_options] || {}

      if options[:id]
        { for: options[:id] }.merge(label_options)
      else
        label_options
      end
    end

    def help_text(attribute, options)
      if options[:hint].present?
        tag.span options[:hint], class: "help-text", id: help_text_id(attribute, options)
      end
    end

    def help_text_id(attribute, options)
      if options[:hint].present?
        "#{custom_label(attribute, "Example", nil).match(/for="([^"]+)"/)[1]}-help-text"
      end
    end

    def field_aria(attribute, options)
      described_by_ids = []
      described_by_ids << error_id(attribute) if field_has_errors?(attribute)

      hint_id = help_text_id(attribute, options)
      described_by_ids << hint_id if hint_id.present?

      aria = {}
      aria[:describedby] = described_by_ids.join(" ") if described_by_ids.any?
      aria[:invalid] = true if field_has_errors?(attribute)
      aria
    end

    def field_has_errors?(attribute)
      object.respond_to?(:errors) && object.errors[attribute].present?
    end

    def error_id(attribute)
      "#{sanitized_object_name}_#{attribute}_error"
    end

    def sanitized_object_name
      object_name.to_s.gsub(/[\[\]]+/, "_").chomp("_")
    end
end
