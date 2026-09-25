class Adm::AttributeEditors::StringComponent < Adm::AttributeEditorComponent
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

  def input_aria_attributes
    return aria_attributes if !invalid?

    aria_attributes.merge(invalid: true, describedby: error_id)
  end

  def invalid?
    @record.errors[@attribute].any?
  end

  def error_message
    @record.errors[@attribute].to_sentence
  end

  def error_id
    return "" if !invalid?

    "#{dom_id(@record)}_#{@attribute}_error"
  end
end
