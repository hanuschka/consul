class Adm::AttributeEditors::ContentTypesComponent < Adm::AttributeEditorComponent
  def initialize(record, attribute, **options)
    @record = record
    @attribute = attribute
    @options = options
  end

  def mime_options
    Setting.mime_types.fetch(@record.content_type_group, {})
  end

  def checked?(mime_value)
    selected_mime_values.include?(mime_value)
  end

  def checkbox_id(extension)
    "#{dom_id(@record)}_#{extension}"
  end

  def aria_attributes
    attrs = {}
    attrs[:labelledby] = @options[:labelledby] if @options[:labelledby].present?
    attrs[:describedby] = @options[:describedby] if @options[:describedby].present?
    attrs
  end

  private

    def selected_mime_values
      @record.value.to_s.split
    end
end
