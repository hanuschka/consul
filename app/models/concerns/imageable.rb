module Imageable
  extend ActiveSupport::Concern

  included do
    has_one :image, as: :imageable, inverse_of: :imageable, dependent: :destroy, class_name: "::Image"
    accepts_nested_attributes_for :image, allow_destroy: true, update_only: true,
      reject_if: proc { |attributes|
        attributes['_destroy'] != '1' &&
          attributes['attachment'].blank? &&
          attributes['cached_attachment'].blank?
      }
  end

  def save(**options)
    super.tap { |result| image&.cache_attachment_for_rerender unless result }
  end

  def update(attributes = {})
    super.tap { |result| image&.cache_attachment_for_rerender unless result }
  end
end
