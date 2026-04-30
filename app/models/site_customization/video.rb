class SiteCustomization::Video < ApplicationRecord
  VALID_VIDEOS = %w[header_video mobile_header_video].freeze
  VALID_FORMATS = ["video/mp4", "video/webm"].freeze
  MAX_FILE_SIZE = 50.megabytes

  alias_attribute :key, :name

  has_one_attached :video

  validates :name, presence: true, uniqueness: true, inclusion: { in: VALID_VIDEOS }
  validates :video,
            file_content_type: { allow: VALID_FORMATS, if: -> { video.attached? }},
            file_size: { less_than_or_equal_to: MAX_FILE_SIZE, if: -> { video.attached? }}

  def self.all_videos
    VALID_VIDEOS.map do |video_name|
      find_by(name: video_name) || create!(name: video_name)
    end
  end

  def persisted_video
    video if persisted_attachment?
  end

  def persisted_attachment?
    video.attachment&.persisted?
  end
end
