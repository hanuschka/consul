class Adm::AttributeEditors::ImageComponent < ApplicationComponent
  def initialize(record, attribute, path, label: nil, updated: false)
    @record = record
    @attribute = attribute
    @path = path
    @label = label
    @updated = updated
  end

  def show_preview?
    @record.send(@attribute).attached? && !@record.send(@attribute).changed?
  end
end
