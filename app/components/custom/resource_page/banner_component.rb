class ResourcePage::BannerComponent < ApplicationComponent
  renders_one :links_section
  attr_reader :resource

  delegate :current_user, :projekt_phase_feature?, to: :helpers

  def initialize(resource:, compact: false)
    @resource = resource
    @compact = compact
  end

  def image_url
    # resource.image&.variant(:large)
    polymorphic_path(resource.image.attachment.variant(
      resize_to_limit: [500, 500],
      saver: { quality: 80 },
      strip: true,
      format: "jpeg"
    ))
  end

  def big_image_url
    # resource.image&.variant(:large)
    polymorphic_path(resource.image.attachment.variant(
      resize_to_limit: [1750, 900],
      saver: { quality: 80 },
      strip: true,
      format: "jpeg"
    ))
  end

  def resource_class
    base_class = "-#{@resource.class.name.split("::").last.downcase}"

    if @resource.image.present?
      base_class += " -with-image"
    end

    if @compact
      base_class += " -compact"
    end

    base_class
  end
end
