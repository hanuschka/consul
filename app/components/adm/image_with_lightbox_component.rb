class Adm::ImageWithLightboxComponent < ApplicationComponent
  DEFAULT_MAX_HEIGHT = 850

  def initialize(display_url:, original_url:, title: nil, max_height: nil, download_label: nil)
    @display_url = display_url
    @original_url = original_url
    @title = title.to_s
    @max_height = max_height || DEFAULT_MAX_HEIGHT
    @download_label = download_label
  end

  private

    attr_reader :display_url, :original_url, :title, :max_height

    def download_label
      @download_label || t(".download_original")
    end

    def frame_style
      "max-height: #{max_height}px;"
    end

    def image_style
      "max-height: #{max_height}px;"
    end
end
