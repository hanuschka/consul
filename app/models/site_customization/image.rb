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

  alias_attribute :key, :name

  has_one_attached :image

  validates :name, presence: true, uniqueness: true, inclusion: { in: ->(*) { VALID_IMAGES.keys }}
  validates :image, file_content_type: { allow: ["image/png", "image/jpeg"], if: -> { image.attached? }}
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

    def check_image
      return unless image.attached?

      unless image.analyzed?
        attachment_changes["image"].upload
        image.analyze
      end

      width = image.metadata[:width]
      height = image.metadata[:height]

      if name.in?(%w[header_image mobile_header_image])
        return
      elsif name.in?(%w[logo_header logo_header_for_transparent])
        errors.add(:image, :max_image_height, max_height: required_height) unless height <= required_height
      else
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
    end
end
