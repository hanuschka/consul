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
    if SETTING_TYPES.any? { |type| @record.is_a?(type) }
      I18n.t("#{@record.class.name.underscore}.#{@record.key}")
    elsif @record.is_a?(SiteCustomization::Image)
      I18n.t("attribute_editor.#{@record.class.name.underscore}.#{@record.name}_label")
    else
      I18n.t("attribute_editor.#{@record.class.name.underscore}.#{@attribute}_label",
             default: @attribute.to_s.humanize)
    end
  end

  def description
    if SETTING_TYPES.any? { |type| @record.is_a?(type) }
      I18n.t("#{@record.class.name.underscore}.#{@record.key}_description")
    elsif @record.is_a?(SiteCustomization::Image)
      I18n.t("attribute_editor.#{@record.class.name.underscore}.#{@record.name}_description")
    else
      I18n.t("attribute_editor.#{@record.class.name.underscore}.#{@attribute}_description",
              default: "attribute_editor.default_description")
    end
  end

  def updated?
    @options.fetch(:updated, false)
  end

  def component_for_type
    case @kind
    when :boolean
      Adm::AttributeEditors::BooleanComponent
    when :image
      Adm::AttributeEditors::ImageComponent
    when :string
      Adm::AttributeEditors::StringComponent
    else
      raise "Unsupported attribute editor kind: #{@kind}"
    end
  end
end
