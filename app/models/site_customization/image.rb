class SiteCustomization::Image < ApplicationRecord
  VALID_IMAGES = {
    ##################################
    "header_image" => [1920, 760],
    "mobile_header_image" => [470, 246],
    ##################################
    "logo_header" => [nil, 80],
    "logo_header_for_transparent" => [nil, 80],
    "social_media_icon" => [470, 246],
    "social_media_icon_twitter" => [246, 246],
    "apple-touch-icon-200" => [200, 200],
    "budget_execution_no_image" => [800, 600],
    "map" => [420, 500],
    "logo_email" => [400, 80],
    "logo_newsletter_email" => [130, 45]
  }.freeze

  VALID_FORMATS = ["image/jpeg", "image/png"].freeze

  # Logos may be uploaded at any dimensions; their display size is enforced in
  # CSS (see _header.scss). Only the file size is bounded server-side.
  LOGO_IMAGE_NAMES = %w[logo_header logo_header_for_transparent].freeze
  LOGO_MAX_FILE_SIZE = 2.megabytes

  # Images that only enforce a minimum size: the stored dimensions act as a
  # floor, larger uploads are allowed (cropped client-side to a fixed ratio).
  MIN_DIMENSION_IMAGE_NAMES = %w[logo_newsletter_email].freeze

  alias_attribute :key, :name

  has_one_attached :image

  validates :name, presence: true, uniqueness: true, inclusion: { in: ->(*) { VALID_IMAGES.keys }}
  validates :image, file_content_type: { allow: ["image/png", "image/jpeg"], if: -> { image.attached? }}
  validates :image, file_size: { less_than_or_equal_to: LOGO_MAX_FILE_SIZE }, if: -> { image.attached? && logo? }
  validate :check_image

  def self.all_images
    VALID_IMAGES.keys.map do |image_name|
      find_by(name: image_name) || create!(name: image_name.to_s)
    end
  end

  def self.image_for(filename)
    image_name = filename.split(".").first

    find_by(name: image_name)&.persisted_image
  end

  def required_width
    VALID_IMAGES[name]&.first
  end

  def required_height
    VALID_IMAGES[name]&.second
  end

  def persisted_image
    image if persisted_attachment?
  end

  def persisted_attachment?
    image.attachment&.persisted?
  end

  private

    def logo?
      name.in?(LOGO_IMAGE_NAMES)
    end

    def min_dimension_image?
      name.in?(MIN_DIMENSION_IMAGE_NAMES)
    end

    def check_image
      return unless image.attached?

      # Header backgrounds and logos are unconstrained in dimensions
      # (logos are capped in CSS); skip the exact-dimension check for them.
      return if logo? || name.in?(%w[header_image mobile_header_image])

      unless image.analyzed?
        attachment_changes["image"].upload
        image.analyze
      end

      width = image.metadata[:width]
      height = image.metadata[:height]

      if min_dimension_image?
        check_minimum_dimensions(width, height)

        return
      end

      wrong_width = width != required_width
      wrong_height = height != required_height

      if wrong_width && wrong_height
        errors.add(:image, :image_dimensions, required_width: required_width, required_height: required_height)
      elsif wrong_width
        errors.add(:image, :image_width, required_width: required_width)
      elsif wrong_height
        errors.add(:image, :image_height, required_height: required_height)
      end
    end

    def check_minimum_dimensions(width, height)
      if width < required_width
        errors.add(:image, :min_image_width, required_min_width: required_width)
      end

      if height < required_height
        errors.add(:image, :min_image_height, required_min_height: required_height)
      end
    end
end
