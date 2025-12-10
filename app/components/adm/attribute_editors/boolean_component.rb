class Adm::AttributeEditors::BooleanComponent < Adm::AttributeEditorComponent
  def initialize(record, attribute, **options)
    @record = record
    @attribute = attribute
    @options = options
  end

  def value_options
    case @record
    when Setting, ProjektSetting, ProjektPhaseSetting
      ["active", ""]
    when SiteCustomization::Page
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
end
