class Adm::AttributeEditors::StringComponent < ApplicationComponent
  def initialize(record, attribute, path, label: nil, updated: false)
    @record = record
    @attribute = attribute
    @path = path
    @label = label
    @updated = updated
  end
end
