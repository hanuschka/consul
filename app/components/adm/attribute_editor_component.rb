class Adm::AttributeEditorComponent < ApplicationComponent
  SETTING_TYPES = [Setting, ProjektSetting, ProjektPhaseSetting].freeze

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
    text = @options[:label].presence || I18n.t(i18n_key(:label), default: @attribute.to_s.humanize)
    field_required? ? "#{text} *" : text
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
    when :select
      Adm::AttributeEditors::SelectComponent
    when :date
      Adm::AttributeEditors::DateComponent
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

  def disabled?
    @options[:disabled] == true
  end

  def wide?
    @options[:wide] == true
  end

  def stacked?
    @kind == :rich_text
  end

  def inline?
    @options[:inline] == true
  end

  def divider?
    @options.fetch(:divider, true)
  end

  def hide_label?
    @options[:hide_label] == true
  end

  private

    def i18n_key(type)
      if @record.is_a?(::ProjektPhaseSetting)
        "projekt_phase_setting.#{@record.projekt_phase.name}.#{@record.key}#{'_description' if type == :description}"
      elsif setting_type?
        "setting.#{@record.key}#{'_description' if type == :description}"
      elsif @record.is_a?(::SiteCustomization::Image)
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

    def field_required?
      return false unless @record.class.respond_to?(:validators_on)

      @record.class.validators_on(@attribute).any? do |v|
        v.is_a?(ActiveModel::Validations::PresenceValidator) &&
          v.options.except(:message).empty?
      end
    end
end
