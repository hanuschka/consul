class ImageSerializer
  include Rails.application.routes.url_helpers

  VARIANT_WIDTHS = [150, 300, 450, 600, 900, 1200, 1920].freeze
  ORIGINAL_VERSION = "original".freeze
  ALL_VARIANT_VERSIONS = (VARIANT_WIDTHS.map(&:to_s) + [ORIGINAL_VERSION]).freeze

  attr_reader :image, :include_variants, :variant_versions

  def initialize(image, include_variants: true, variant_versions: nil)
    @image = image
    @include_variants = include_variants
    @variant_versions = filter_variant_versions(variant_versions)
  end

  def serialize
    return nil if image.nil? || !image.attached?

    image_data = {
      id: image.id,
      title: image.title,
      credits: image.credits,
      ai_generated: image.ai_generated,
      url: rails_blob_url(image.attachment, **image_url_options)
    }

    if include_variants
      image_data[:variants] = serialize_variants
    end

    image_data
  end

  private

  def serialize_variants
    variant_versions.each_with_object({}) do |version, variants|
      variants[version.to_sym] = variant_url_for(version)
    end
  end

  def variant_url_for(version)
    if version == ORIGINAL_VERSION
      return rails_blob_url(image.attachment, **image_url_options)
    end

    variant_url_by_width(version.to_i)
  end

  def variant_url_by_width(width)
    return nil if !image.attachment.attached?

    variant = image.attachment_variant(resize_to_limit: [width, nil])
    rails_representation_url(variant, **image_url_options)
  rescue StandardError
    nil
  end

  def filter_variant_versions(versions)
    return ALL_VARIANT_VERSIONS if versions.blank?

    requested = Array(versions).map(&:to_s)

    ALL_VARIANT_VERSIONS.select { |version| requested.include?(version) }
  end

  def image_url_options
    UrlOptions.default
  end
end
