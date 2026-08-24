module Imageable
  extend ActiveSupport::Concern

  included do
    has_one :image, as: :imageable, inverse_of: :imageable, dependent: :destroy, class_name: "::Image"
    accepts_nested_attributes_for :image, allow_destroy: true, update_only: true,
      reject_if: proc { |attributes|
        next false if attributes["_destroy"] == "1"
        next false if attributes["attachment"].present? || attributes["cached_attachment"].present?

        # An edit that only changes the image's own fields (title, credits, the
        # AI marker) carries no file, and must still reach the existing image.
        # Only a payload for an image that does not exist yet has nothing to do.
        attributes["id"].blank?
      }
  end

  def save(**options)
    super.tap { |result| image&.cache_attachment_for_rerender unless result }
  end

  def update(attributes = {})
    super.tap { |result| image&.cache_attachment_for_rerender unless result }
  end
end
