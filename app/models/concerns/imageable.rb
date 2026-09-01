module Imageable
  extend ActiveSupport::Concern

  included do
    has_one :image, as: :imageable, inverse_of: :imageable, dependent: :destroy, class_name: "::Image"
    accepts_nested_attributes_for :image, allow_destroy: true, update_only: true,
      reject_if: proc { |attributes|
        next false if attributes["_destroy"] == "1"

        # A rendered file field posts an empty string when the uploader kept the
        # current file, and assigning that to the attachment raises before any
        # validation runs. Dropping the empty keys here leaves an edit that only
        # changes the image's own fields -- title, credits, the AI marker -- free
        # to reach the existing image.
        attributes.delete("attachment") if attributes["attachment"].blank?
        attributes.delete("cached_attachment") if attributes["cached_attachment"].blank?

        next false if attributes.key?("attachment") || attributes.key?("cached_attachment")

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
