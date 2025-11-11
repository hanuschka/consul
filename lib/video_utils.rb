module VideoUtils
  YOUTUBE_PLATFORM = 'youtube'
  VIMEO_PLATFORM = 'vimeo'

  VideoInfo = Struct.new(:external_id, :platform, keyword_init: true)

  def self.extract_info(url)
    platform =
      if url.include?("youtube.")
        YOUTUBE_PLATFORM
      elsif url.include?("vimeo.")
        VIMEO_PLATFORM
      end

    external_id =
      case platform
      when YOUTUBE_PLATFORM
        match = url.match(/(?:v=|embed|live\/)(?<youtube_id>[\w-]+)/)

        if match.present?
          match[:youtube_id]
        end
      when VIMEO_PLATFORM
        match = url.match(/vimeo\.com\/(?<vimeo_id>\w+)/)

        if match.present?
          match[:vimeo_id]
        end
      end

    VideoInfo.new(platform: platform, external_id: external_id)
  end

  def self.embed_url(url)
    return if url.blank?

    video_info = extract_info(url)

    case video_info.platform
    when YOUTUBE_PLATFORM
      "https://www.youtube.com/embed/#{video_info.external_id}"
    when VIMEO_PLATFORM
      "https://player.vimeo.com/video/#{video_info.external_id}"
    end
  end
end
