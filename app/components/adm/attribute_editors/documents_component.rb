class Adm::AttributeEditors::DocumentsComponent < ApplicationComponent
  def initialize(documentable, add_path:, remove_path:)
    @documentable = documentable
    @add_path = add_path
    @remove_path = remove_path
  end

  attr_reader :documentable, :add_path, :remove_path

  def remove_path_for(document)
    "#{remove_path}?document_id=#{document.id}"
  end

  delegate :documents, to: :documentable

  def max_documents_allowed
    documentable.class.max_documents_allowed
  end

  def max_file_size
    documentable.class.max_file_size
  end

  def accepted_content_types
    Document.humanized_accepted_content_types
  end

  def can_add_more?
    documents.count < max_documents_allowed
  end

  def frame_id
    dom_id(documentable, :documents)
  end
end
