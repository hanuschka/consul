class ProjektPointOfInterestCategory < ApplicationRecord
  ALLOWED_ICON_CONTENT_TYPES = %w[image/svg+xml image/png image/jpeg].freeze
  MAX_ICON_BYTE_SIZE = 512.kilobytes

  belongs_to :projekt_phase
  belongs_to :masterportal_collection, optional: true
  has_many :projekt_point_of_interest_pins, dependent: :nullify
  has_one_attached :icon_image

  validates :name, presence: true
  validates :color, presence: true
  validates :icon, presence: true
  validate :icon_image_content_type
  validate :icon_image_size

  scope :ordered, -> { order(name: :asc) }
  scope :collection_backed, -> { where.not(masterportal_collection_id: nil) }
  scope :manual, -> { where(masterportal_collection_id: nil) }

  def collection_backed?
    masterportal_collection_id.present?
  end

  private

    def icon_image_content_type
      return if !icon_image.attached?

      content_type = icon_image.blob.content_type

      if ALLOWED_ICON_CONTENT_TYPES.exclude?(content_type)
        errors.add(:icon_image, :invalid_content_type)
        return
      end

      return if content_type != "image/svg+xml"
      return if Masterportal::SvgSanitizer.safe?(icon_image.blob.download)

      errors.add(:icon_image, :unsafe_svg)
    end

    def icon_image_size
      return if !icon_image.attached?
      return if icon_image.blob.byte_size <= MAX_ICON_BYTE_SIZE

      errors.add(:icon_image, :too_large)
    end
end
