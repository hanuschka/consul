class Adm::AttributeEditors::DateComponent < Adm::AttributeEditorComponent
  def initialize(record, attribute, **options)
    @record = record
    @attribute = attribute
    @options = options
  end

  def aria_attributes
    attrs = {}
    attrs[:labelledby] = @options[:labelledby] if @options[:labelledby].present?
    attrs[:describedby] = @options[:describedby] if @options[:describedby].present?
    attrs
  end
end
