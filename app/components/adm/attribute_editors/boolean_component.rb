class Adm::AttributeEditors::BooleanComponent < Adm::AttributeEditorComponent
  def initialize(record, attribute, **options)
    @record = record
    @attribute = attribute
    @options = options
  end

  def value_options
    if SETTING_TYPES.any? { |type| @record.is_a?(type) }
      ["active", ""]
    elsif @record.is_a?(::SiteCustomization::Page) && @attribute == :status
      ["published", "draft"]
    else
      [true, false]
    end
  end

  def toggled_on?
    @toggled_on ||= @record.public_send(@attribute) == value_options.first
  end

  def alternate_value
    @alternate_value ||= toggled_on? ? value_options.last : value_options.first
  end

  def aria_attributes
    attrs = { checked: toggled_on? }
    attrs[:labelledby] = @options[:labelledby] if @options[:labelledby].present?
    attrs[:describedby] = @options[:describedby] if @options[:describedby].present?
    attrs
  end
end
