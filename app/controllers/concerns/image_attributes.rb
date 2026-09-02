module ImageAttributes
  extend ActiveSupport::Concern

  def image_attributes
    [:id, :title, :attachment, :cached_attachment, :credits, :ai_generated, :user_id, :_destroy]
  end

  def image_attributes_api
    [:title, :attachment, :credits, :ai_generated, :_destroy]
  end
end
