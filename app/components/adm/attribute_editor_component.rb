class Adm::AttributeEditorComponent < ApplicationComponent
  SETTING_TYPES = [Setting, ProjektSetting].freeze

  def initialize(record, attribute, kind, **options)
    @record = record
    @attribute = attribute
    @kind = kind.to_sym
    @options = options
  end

  def path
    return @options[:path] if @options[:path].present?

    adm_attribute_path(record_type: record_type_key, id: @record.id)
  end

  def label
    @options[:label].presence || I18n.t(i18n_key(:label), default: @attribute.to_s.humanize)
  end

  def description
    @options[:description].presence || I18n.t(i18n_key(:description), default: nil)
  end

  def component_for_type
    case @kind
    when :boolean
      Adm::AttributeEditors::BooleanComponent
    when :string
      Adm::AttributeEditors::StringComponent
    when :rich_text
      Adm::AttributeEditors::RichTextComponent
    when :image
      Adm::AttributeEditors::ImageComponent
    when :color
      Adm::AttributeEditors::ColorComponent
    else
      raise "Unsupported attribute editor kind: #{@kind}"
    end
  end

  def aria_options
    {
      labelledby: "#{dom_id(@record)}_#{@attribute}_label",
      describedby: "#{dom_id(@record)}_#{@attribute}_description"
    }
  end

  private

    def i18n_key(type)
      if setting_type?
        "setting.#{@record.key}#{'_description' if type == :description}"
      elsif @record.is_a?(SiteCustomization::Image)
        "adm.attribute_editor.#{record_type_key}.#{@record.name}_#{type}"
      else
        ["adm.attribute_editor", record_type_key, suffix, "#{@attribute}_#{type}"].compact.join(".")
      end
    end

    def record_type_key
      @record_type_key ||= @record.class.base_class.name.underscore
    end

    def suffix
      return unless @record.is_a?(::SiteCustomization::Page)

      return "projekt" if @record.projekt.present?
      return "landing" if @record.landing?
    end

    def setting_type?
      SETTING_TYPES.any? { |type| @record.is_a?(type) }
    end
end
