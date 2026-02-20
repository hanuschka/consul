class Adm::AttributeEditors::DocumentsComponent < ApplicationComponent
  def initialize(documentable, update_path:)
    @documentable = documentable
    @update_path = update_path
  end

  attr_reader :documentable, :update_path
end
