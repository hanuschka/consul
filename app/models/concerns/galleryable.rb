module Galleryable
  extend ActiveSupport::Concern

  included do
    has_many :images, as: :imageable, inverse_of: :imageable, dependent: :destroy
    accepts_nested_attributes_for :images, allow_destroy: true, update_only: true
  end

  def save(**options)
    super.tap { |result| images.each(&:cache_attachment_for_rerender) unless result }
  end

  def update(attributes = {})
    super.tap { |result| images.each(&:cache_attachment_for_rerender) unless result }
  end
end
