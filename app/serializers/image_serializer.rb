class ImageSerializer
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
      url: image.url
    }

    # Include all image variants if requested
    if include_variants
      image_data[:variants] = serialize_variants
    end

    image_data
  end

  private

  def serialize_variants
    {
      large: image.variant(:large)&.url,
      projekt_image: image.variant(:projekt_image)&.url,
      medium: image.variant(:medium)&.url,
      thumb: image.variant(:thumb)&.url,
      thumb_wider: image.variant(:thumb_wider)&.url,
      banner: image.variant(:banner)&.url,
      popup: image.variant(:popup)&.url,
      thumb2: image.variant(:thumb2)&.url,
      projekt_event_thumb: image.variant(:projekt_event_thumb)&.url,
      card_thumb: image.variant(:card_thumb)&.url
    }
  end
end
