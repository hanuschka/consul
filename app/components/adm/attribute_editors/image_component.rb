class Adm::AttributeEditors::ImageComponent < Adm::AttributeEditorComponent
  def initialize(record, attribute, **options)
    @record = record
    @attribute = attribute
    @options = options
  end

end
