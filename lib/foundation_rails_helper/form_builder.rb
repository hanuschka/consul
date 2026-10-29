# Copied from the foundation_rails_helper gem 4.0.1 (MIT, see LICENSE in this
# directory), whose last release caps Rails below 7.1
class FoundationRailsHelper::FormBuilder < ActionView::Helpers::FormBuilder
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::OutputSafetyHelper

  BUTTON_CLASS = "success button".freeze
  INPUT_SIZES = %i[small medium large].freeze
  FULL_WIDTH = 12

  %w[
    file_field email_field text_field text_area telephone_field phone_field
    url_field number_field date_field datetime_field datetime_local_field
    month_field week_field time_field range_field search_field color_field
  ].each do |method_name|
    define_method(method_name) do |*args|
      attribute = args[0]
      options = args[1] || {}

      field(attribute, options) do |opts|
        super(attribute, opts)
      end
    end
  end

  def label(attribute, text = nil, options = {})
    if error?(attribute)
      options[:class] ||= ""
      options[:class] += " is-invalid-label"
    end

    super(attribute, (text || "").html_safe, options)
  end

  def check_box(attribute, options = {}, checked_value = "1", unchecked_value = "0")
    custom_label(attribute, options[:label], options[:label_options]) do
      options.delete(:label)
      options.delete(:label_options)
      super(attribute, options, checked_value, unchecked_value)
    end + error_and_help_text(attribute, options)
  end

  def radio_button(attribute, tag_value, options = {})
    options[:label_options] ||= {}
    label_options = options.delete(:label_options).merge!(value: tag_value)
    label_text = options.delete(:label)
    radio = @template.radio_button(@object_name, attribute, tag_value, objectify_options(options))

    return radio.html_safe if label_text == false

    "#{radio}#{label(attribute, label_text, label_options)}".html_safe
  end

  def password_field(attribute, options = {})
    field attribute, options do |opts|
      super(attribute, opts.merge(autocomplete: :off))
    end
  end

  def datetime_select(attribute, options = {}, html_options = {})
    field attribute, options, html_options do |html_opts|
      super(attribute, options, html_opts.merge(autocomplete: :off))
    end
  end

  def date_select(attribute, options = {}, html_options = {})
    field attribute, options, html_options do |html_opts|
      super(attribute, options, html_opts.merge(autocomplete: :off))
    end
  end

  def time_zone_select(attribute, priorities = nil, options = {}, html_options = {})
    field attribute, options, html_options do |html_opts|
      super(attribute, priorities, options, html_opts.merge(autocomplete: :off))
    end
  end

  def select(attribute, choices, options = {}, html_options = {})
    field attribute, options, html_options do |html_opts|
      html_options[:autocomplete] ||= :off
      super(attribute, choices, options, html_opts)
    end
  end

  def collection_select(
    attribute, collection, value_method, text_method, options = {}, html_options = {}
  )
    field attribute, options, html_options do |html_opts|
      html_options[:autocomplete] ||= :off
      super(attribute, collection, value_method, text_method, options, html_opts)
    end
  end

  def grouped_collection_select(
    attribute, collection, group_method, group_label_method, option_key_method,
    option_value_method, options = {}, html_options = {}
  )
    field attribute, options, html_options do |html_opts|
      html_options[:autocomplete] ||= :off
      super(
        attribute, collection, group_method, group_label_method, option_key_method,
        option_value_method, options, html_opts
      )
    end
  end

  def submit(value = nil, options = {})
    options[:class] ||= BUTTON_CLASS
    super
  end

  def error_for(attribute, options = {})
    return if !error?(attribute)

    class_name = ["form-error is-visible", options[:class]].compact.join(" ")
    error_messages = object.errors[attribute].join(", ")

    if options[:html_safe_errors]
      error_messages = error_messages.html_safe
    end

    content_tag(:small, error_messages, class: class_name.sub("is-invalid-input", ""))
  end

  private

    def error?(attribute)
      object.respond_to?(:errors) && object.errors[attribute].present?
    end

    def default_label_text(object, attribute)
      if object.class.respond_to?(:human_attribute_name)
        object.class.human_attribute_name(attribute)
      else
        attribute.to_s.humanize
      end
    end

    def custom_label(attribute, text, options)
      if text == false
        return block_given? ? yield.html_safe : "".html_safe
      end

      if text.nil? || text == true
        text = default_label_text(object, attribute)
      end

      if block_given?
        text = safe_join([yield, text.html_safe])
      end

      label(attribute, text, options || {})
    end

    def column_classes(options)
      "#{FoundationRailsHelper::SizeClassCalculator.new(options).classes} columns"
    end

    def tag_from_options(name, options)
      return "".html_safe if options.blank? || options[:value].blank?

      content_tag(:div, content_tag(:span, options[:value], class: name), class: column_classes(options))
    end

    def wrap_prefix_and_postfix(block, prefix_options, postfix_options)
      size_options = [prefix_options, postfix_options].select(&:present?)

      return block if size_options.none? { (it.keys & INPUT_SIZES).any? }

      input_size = INPUT_SIZES.index_with do |size|
        FULL_WIDTH - size_options.sum { it.fetch(size, 0).to_i }
      end
      prefix = tag_from_options("prefix", prefix_options)
      postfix = tag_from_options("postfix", postfix_options)
      input = content_tag(:div, block, class: column_classes(input_size))

      content_tag(:div, prefix + input + postfix, class: "row collapse")
    end

    def error_and_help_text(attribute, options = {})
      help_text = options[:help_text] ? content_tag(:p, options[:help_text], class: "help-text") : ""

      "#{help_text}#{error_for(attribute, options)}".html_safe
    end

    def field_label(attribute, options)
      return "".html_safe if !auto_labels && !options[:label]

      custom_label(attribute, options[:label], options[:label_options])
    end

    def field(attribute, options, html_options = nil)
      html = field_label(attribute, options)
      class_options = html_options || options

      if error?(attribute)
        class_options[:class] = class_options[:class].to_s
        class_options[:class] += " is-invalid-input"
      end

      options.delete(:label)
      options.delete(:label_options)
      help_text = options.delete(:help_text)
      prefix = options.delete(:prefix)
      postfix = options.delete(:postfix)

      html += wrap_prefix_and_postfix(yield(class_options), prefix, postfix)
      html + error_and_help_text(attribute, options.merge(help_text: help_text))
    end

    def auto_labels
      @options[:auto_labels].nil? || @options[:auto_labels]
    end
end
