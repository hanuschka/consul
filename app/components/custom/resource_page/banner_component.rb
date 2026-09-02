class ResourcePage::BannerComponent < ApplicationComponent
  renders_one :links_section
  renders_many :additional_resource_details
  attr_reader :resource

  delegate :current_user, :projekt_feature?, :projekt_phase_feature?, :format_date_range, to: :helpers

  def initialize(resource:, compact: false, heading_level: nil)
    @resource = resource
    @compact = compact
    @heading_level = heading_level
  end

  def heading_level
    @heading_level || (@compact ? :h2 : :h1)
  end

  def image_url
    return nil unless resource.image&.attached?

    polymorphic_path(resource.image.attachment_variant(
      # TODO Resize to `[415, 260]` when image croping will be inroduced
      # resize_to_limit: [415, 260],
      resize_to_limit: [500, 500],
      saver: { quality: 80 },
      format: "jpeg"
    ))
  rescue ArgumentError, URI::InvalidURIError, ActiveStorage::InvariableError
    nil
  end

  def big_image_url
    return nil unless resource.image&.attached?

    polymorphic_path(resource.image.attachment_variant(
      resize_to_limit: [1750, 900],
      saver: { quality: 80 },
      format: "jpeg"
    ))
  rescue ArgumentError, URI::InvalidURIError, ActiveStorage::InvariableError
    nil
  end

  def resource_class
    base_class = "-#{@resource.class.name.split("::").last.downcase}"

    if @resource.image&.attached?
      base_class += " -with-image"
    end

    if @compact
      base_class += " -compact"
    end

    base_class
  end

  def date_string
    if resource.is_a?(Poll)
      format_date_range(resource.projekt_phase.start_date, resource.projekt_phase.end_date, separator: t("custom.polls.poll.date.to"))
    else
      l(resource.created_at, format: :new_date_with_year)
    end
  end

  def show_projekt_link?
    return false unless resource.respond_to?(:projekt)

    projekt_feature?(resource.projekt, "general.show_related_projekt_link")
  end
end
