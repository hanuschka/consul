class Shared::ImageWithLightboxComponent < ApplicationComponent
  def initialize(image_url:, original_url:, alt:, gallery: nil, loading: "lazy")
    @image_url = image_url
    @original_url = original_url
    @alt = alt
    @gallery = gallery
    @loading = loading
  end

  private

    attr_reader :image_url, :original_url, :alt, :gallery, :loading
end
