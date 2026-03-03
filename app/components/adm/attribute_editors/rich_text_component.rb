class Adm::AttributeEditors::RichTextComponent < Adm::AttributeEditorComponent
  delegate :ck_editor_class, to: :helpers

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

  def sanitized_value
    AdminWYSIWYGSanitizer.new.sanitize(@record.public_send(@attribute))
  end
end
