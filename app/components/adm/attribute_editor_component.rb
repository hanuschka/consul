class Adm::AttributeEditorComponent < ApplicationComponent
  include Turbo::FramesHelper

  SETTING_TYPES = [Setting].freeze

  def initialize(record, attribute, kind, **options)
    @record = record
    @attribute = attribute
    @kind = kind.to_sym
    @options = options
  end

  def path
    return @options[:path] if @options[:path].present?

    return adm_setting_path(@record) if @record.is_a?(Setting)
    return adm_site_customization_image_path(@record) if @record.is_a?(SiteCustomization::Image)

    raise "No path provided for attribute editor"
  end

  def label
    return @options[:label] if @options[:label].present?

    if SETTING_TYPES.any? { |type| @record.is_a?(type) }
      I18n.t("#{@record.class.name.underscore}.#{@record.key}")
    elsif @record.is_a?(SiteCustomization::Image)
      I18n.t("adm.attribute_editor.#{@record.class.name.underscore}.#{@record.name}_label")
    else
      I18n.t(["adm.attribute_editor.#{@record.class.name.underscore}", suffix, "#{@attribute}_label"].compact.join("."),
             default: @attribute.to_s.humanize)
    end
  end

  def description
    return @options[:description] if @options[:description].present?

    if SETTING_TYPES.any? { |type| @record.is_a?(type) }
      I18n.t("#{@record.class.name.underscore}.#{@record.key}_description")
    elsif @record.is_a?(SiteCustomization::Image)
      I18n.t("adm.attribute_editor.#{@record.class.name.underscore}.#{@record.name}_description")
    else
      I18n.t(["adm.attribute_editor.#{@record.class.name.underscore}", suffix, "#{@attribute}_description"].compact.join("."),
             default: "adm.attribute_editor.default_description")
    end
  end

  def component_for_type
    case @kind
    when :boolean
      Adm::AttributeEditors::BooleanComponent
    when :string
      Adm::AttributeEditors::StringComponent
    when :image
      Adm::AttributeEditors::ImageComponent
    when :color
      Adm::AttributeEditors::ColorComponent
    else
      raise "Unsupported attribute editor kind: #{@kind}"
    end
  end

  def suffix
    if @record.is_a?(::SiteCustomization::Page) && @record.landing?
      "landing"
    else
      nil
    end
  end
end
