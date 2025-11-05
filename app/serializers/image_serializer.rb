class ImageSerializer
  include Rails.application.routes.url_helpers

  attr_reader :image, :include_variants

  def initialize(image, include_variants: true)
    @image = image
    @include_variants = include_variants
  end

  def serialize
    return nil if image.nil? || !image.attached?

    image_data = {
      id: image.id,
      title: image.title,
      credits: image.credits,
      url: rails_blob_url(image.attachment, host: host)
    }

    if include_variants
      image_data[:variants] = serialize_variants
    end

    image_data
  end

  private

  def serialize_variants
    {
      large: variant_url(:large),
      projekt_image: variant_url(:projekt_image),
      thumb: variant_url(:thumb),
      thumb_wider: variant_url(:thumb_wider),
    }
  end

  def variant_url(style)
    variant = image.variant(style)
    return nil unless variant

    rails_representation_url(variant, host: host)
  end

  def host
    "#{Rails.application.secrets.server_name}:3000"
  end
end
