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
      url: rails_blob_url(image.attachment, **image_url_options)
    }

    if include_variants
      image_data[:variants] = serialize_variants
    end

    image_data
  end

  private

  def serialize_variants
    {
      "150": variant_url_by_width(150),
      "300": variant_url_by_width(300),
      "450": variant_url_by_width(450),
      "600": variant_url_by_width(600),
      "900": variant_url_by_width(900),
      "1200": variant_url_by_width(1200),
      "1920": variant_url_by_width(1920),
      "original": rails_blob_url(image.attachment, **image_url_options)
    }
  end

  def variant_url_by_width(width)
    return nil unless image.attachment.attached?

    variant = image.attachment.variant(resize_to_limit: [width, nil])
    rails_representation_url(variant, **image_url_options)
  rescue StandardError
    nil
  end

  def image_url_options
    UrlOptions.default
  end
end
