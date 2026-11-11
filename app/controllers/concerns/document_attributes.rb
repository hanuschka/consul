module DocumentAttributes
  extend ActiveSupport::Concern

  def document_attributes
    [:id, :title, :attachment, :cached_attachment, :user_id, :_destroy]
  end

  def document_attributes_api
    [:id, :title, :attachment, :cached_attachment, :_destroy]
  end
end
