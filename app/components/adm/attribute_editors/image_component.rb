class Adm::AttributeEditors::ImageComponent < Adm::AttributeEditorComponent
  def initialize(record, attribute, **options)
    @record = record
    @attribute = attribute
    @options = options
  end

  def show_preview?
    @record.send(@attribute).attached? && !@record.send(@attribute).changed?
  end
end
