class Adm::AttributeEditorComponent < ApplicationComponent
  include Turbo::FramesHelper

  def initialize(record, attribute, **options)
    @record = record
    @attribute = attribute
    @options = options
    @kind = options[:kind] || :string
  end

  def label
    return @options[:label] if @options[:label].present?
    return I18n.t("#{@record.class.name.underscore}.#{@record.key}") if @record.is_a?(Setting) || @record.is_a?(SiteCustomization::Image)

    @record.class.human_attribute_name(@attribute)
  end

  def hint
    return I18n.t("#{@record.class.name.underscore}.#{@record.key}_description") if @record.is_a?(Setting) || @record.is_a?(SiteCustomization::Image)

    @options[:hint] || ""
  end

  def updated?
    @options.fetch(:updated, false)
  end

  def path
    return @options[:path] if @options[:path].present?

    return adm_setting_path(@record) if @record.is_a?(Setting)
    return adm_site_customization_image_path(@record) if @record.is_a?(SiteCustomization::Image)

    raise "No path provided for attribute editor"
  end

  def component_for_type
    case @kind
    when :boolean
      Adm::AttributeEditors::BooleanComponent
    when :image
      Adm::AttributeEditors::ImageComponent
    else
      Adm::AttributeEditors::StringComponent
    end
  end
end
