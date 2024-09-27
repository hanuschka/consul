class Image < ApplicationRecord
  include Attachable

  def self.styles
    {
      large: { coalesce: true, resize: "x#{Setting["uploads.images.min_height"]}", loader: { page: nil }},
      projekt_image: { coalesce: true, gravity: "center", resize: "620x390^", crop: "620x390+0+0", loader: { page: nil }},
      medium: { coalesce: true, gravity: "center", resize: "300x300^", crop: "300x300+0+0", loader: { page: nil }},
      thumb: { coalesce: true, gravity: "center", resize: "140x245^", crop: "140x245+0+0", loader: { page: nil }},
      thumb_wider: { coalesce: true, gravity: "center", resize: "185x280^", crop: "185x280+0+0", loader: { page: nil }},
      banner: { coalesce: true, gravity: "center", resize: "1920x250^", crop: "1920x250+0+0", loader: { page: nil }},
      popup: { coalesce: true, gravity: "center", resize: "140x140^", crop: "140x140+0+0", loader: { page: nil }},
      thumb2: { coalesce: true, gravity: "center", resize: "100x100^", crop: "100x100+0+0", loader: { page: nil }},
      projekt_event_thumb: { coalesce: true, gravity: "center", resize: "300x200^", crop: "300x200+0+0", loader: { page: nil }},
      card_thumb: { coalesce: true, gravity: "center", resize: "300x300^", loader: { page: nil }}
    }
  end

  belongs_to :user
  belongs_to :imageable, polymorphic: true, touch: true

  # validates :title, presence: true
  validate :validate_title_length
  validates :user_id, presence: true
  validates :imageable_id, presence: true,         if: -> { persisted? }
  validates :imageable_type, presence: true,       if: -> { persisted? }
  validate :validate_image_dimensions, if: -> { attachment.attached? && attachment.new_record? }

  def self.max_file_size
    Setting["uploads.images.max_size"].to_i
  end

  def self.accepted_content_types
    Setting["uploads.images.content_types"]&.split(" ") || ["image/jpeg"]
  end

  def self.humanized_accepted_content_types
    Setting.accepted_content_types_for("images").join(", ")
  end

  def self.save_image_from_url(url)
    whitelisted_urls = [
      "http://graph.facebook.com/",
      "https://graph.facebook.com/",
      "https://demokratie.today/"
    ]
    return unless whitelisted_urls.any? { |whitelisted_url| url.start_with?(whitelisted_url) }

    require "open-uri"

    tmp_folder = Rails.root.join("tmp")
    filename = "#{SecureRandom.hex(16)}.jpg"
    destination_path = File.join(tmp_folder, filename)

    open(destination_path, "wb") do |file|
      URI.open(url, "rb") do |img|
        file.write(img.read)
      end
    end

    destination_path
  end

  def max_file_size
    self.class.max_file_size
  end

  def accepted_content_types
    self.class.accepted_content_types
  end

  def variant(style)
    if style
      if attachment.attached?
        attachment&.variant(self.class.styles[style])
      end
    else
      attachment
    end
  end

  def attached?
    attachment.attached?
  end

  private

    def association_name
      :imageable
    end

    def imageable_class
      association_class
    end

    def validate_image_dimensions
      if accepted_content_types.include?(attachment_content_type)
        return true if imageable_class == Widget::Card
        return true if imageable_class == SiteCustomization::Page
        return true if imageable_class == User && title == "avatar" && imageable.new_record?

        unless attachment.analyzed?
          attachment_changes["attachment"].upload
          attachment.analyze
        end

        width = attachment.metadata[:width]
        height = attachment.metadata[:height]
        min_width = Setting["uploads.images.min_width"].to_i
        min_height = Setting["uploads.images.min_height"].to_i
        errors.add(:attachment, :min_image_width, required_min_width: min_width) if width < min_width
        errors.add(:attachment, :min_image_height, required_min_height: min_height) if height < min_height
      end
    end

    def validate_title_length
      if title.present?
        title_min_length = Setting["uploads.images.title.min_length"].to_i
        title_max_length = Setting["uploads.images.title.max_length"].to_i

        if title.size < title_min_length
          errors.add(:title, I18n.t("errors.messages.too_short", count: title_min_length))
        end

        if title.size > title_max_length
          errors.add(:title, I18n.t("errors.messages.too_long", count: title_max_length))
        end
      end
    end
end
